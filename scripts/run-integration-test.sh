#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAILABLE_TESTS=$(cd "$SCRIPT_DIR/../tasks" && ls deploy-*.yaml | sed 's/^deploy-\(.*\)\.yaml$/\1/' | sort)

function show_help() {
  echo "Usage: $0 <test-name> [--cleanup]"
  echo ""
  echo "Runs the specified integration test in a temporary namespace."
  echo ""
  echo "Available tests:"
  for test in $AVAILABLE_TESTS; do
    echo "  - $test"
  done
  echo ""
  echo "Options:"
  echo "  --cleanup     Delete the test namespace after completion"
  echo "  -h, --help    Show this help message"
  exit 0
}

# Help flag
if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
fi

TEST_NAME="$1"
CLEANUP="${2:-}"

if ! echo "$AVAILABLE_TESTS" | grep -q "^${TEST_NAME}$"; then
  echo "❌ Unknown test: $TEST_NAME"
  echo "Run with --help to see available tests."
  exit 1
fi

TMP_NS="ci-test-${TEST_NAME}-$(date +%s)"

echo "👉 Creating temporary namespace: ${TMP_NS}"
kubectl create ns "${TMP_NS}"

if ! kubectl get secret pipelines-as-code-secret -n "$TMP_NS" &> /dev/null; then
  echo "📋 Copying pipelines-as-code-secret into ${TMP_NS}..."
  kubectl get secret pipelines-as-code-secret -n pipelines-as-code -o yaml | \
    sed "s/namespace: pipelines-as-code/namespace: ${TMP_NS}/" | \
    kubectl apply -f -
fi

DEPLOY_TASK="$SCRIPT_DIR/../tasks/deploy-${TEST_NAME}.yaml"
TEST_TASK="$SCRIPT_DIR/../tasks/test-${TEST_NAME}.yaml"
PIPELINE_RUN="$SCRIPT_DIR/../.tekton/integration-test-${TEST_NAME}.yaml"
UTILS="$SCRIPT_DIR/../tasks/utils.yaml"

echo "📥 Applying shared tasks to ${TMP_NS}..."
for file in "$DEPLOY_TASK" "$TEST_TASK" "$UTILS"; do
  echo " - $file"
  kubectl apply -n "${TMP_NS}" -f "$file"
done

echo "🚀 Launching PipelineRun: $PIPELINE_RUN"
kubectl create -n "${TMP_NS}" -f "$PIPELINE_RUN"

echo "⏳ Waiting for PipelineRun to start..."
PR_NAME=""
until [[ -n "$PR_NAME" ]]; do
  PR_NAME=$(kubectl get pipelineruns -n "${TMP_NS}" -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || true)
  sleep 1
done

echo "🔁 Waiting for PipelineRun to complete: $PR_NAME"
kubectl wait --for=condition=Succeeded --timeout=300s pipelinerun "$PR_NAME" -n "${TMP_NS}" || {
  echo "❌ PipelineRun failed or timed out."
  kubectl logs -n "${TMP_NS}" -l tekton.dev/pipelineRun="$PR_NAME" --all-containers || true
  [[ "$CLEANUP" == "--cleanup" ]] && kubectl delete ns "${TMP_NS}"
  exit 1
}

echo "✅ PipelineRun completed successfully."
echo "📦 Output:"
kubectl get pipelinerun "$PR_NAME" -n "${TMP_NS}" -o=jsonpath="{.status.pipelineResults[?(@.name=='test-output')].value}" || echo "⚠️ No test-output result found."

if [[ "$CLEANUP" == "--cleanup" ]]; then
  echo "🧹 Cleaning up namespace: ${TMP_NS}"
  kubectl delete ns "${TMP_NS}"
else
  echo ""
  echo "🧾 View logs with:"
  echo "kubectl logs -n ${TMP_NS} -l tekton.dev/pipelineRun=${PR_NAME} --all-containers"
  echo "🧼 To manually delete:"
  echo "kubectl delete ns ${TMP_NS}"
fi

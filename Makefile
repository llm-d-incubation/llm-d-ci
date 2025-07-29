# Namespace where you want to apply the tasks
NAMESPACE ?= default

# Files
PIPELINE_RUNS = $(wildcard .tekton/integration-test-*.yaml)
DEPLOY_TASKS = $(wildcard tasks/deploy-*.yaml)
TEST_TASKS   = $(wildcard tasks/test-*.yaml)

# All task files
TASKS = $(DEPLOY_TASKS) $(TEST_TASKS)

.PHONY: all apply-tasks apply-pipelines apply-all test-run clean

## Apply only shared tasks
apply-tasks:
	@echo "Applying tasks to namespace $(NAMESPACE)..."
	@for task in $(TASKS); do \
		echo " - $$task"; \
		kubectl apply -n $(NAMESPACE) -f $$task; \
	done

## Apply only integration test PipelineRuns
apply-pipelines:
	@echo "Applying integration PipelineRun definitions..."
	@for pr in $(PIPELINE_RUNS); do \
		echo " - $$pr"; \
		kubectl apply -n $(NAMESPACE) -f $$pr; \
	done

## Apply everything
apply-all: apply-tasks apply-pipelines

## Trigger a test run (example: scheduler-routing)
test-run:
	@echo "Running test PipelineRun: scheduler-routing"
	kubectl create -n $(NAMESPACE) -f .tekton/integration-test-scheduler-routing.yaml

## Clean all deployments (used after local testing)
clean:
	@echo "Deleting all test deployments..."
	kubectl delete deploy -n $(NAMESPACE) --ignore-not-found \
		llm-d scheduler routing-sidecar autoscaler kv-cache pd-utils modelservice

# Calling Shared Integration Test Pipelines

This directory provides example PipelineRun stubs and guidance for invoking centralized integration tests defined in the `llm-d-incubation/llm-d-ci` repository.

Each integration test validates interoperability across one or more `llm-d` components using Pipelines-as-Code (Konflux). Shared test definitions live in `.tekton/` and are referenced from this directory via lightweight stubs.

## Available Integration Test Pipelines

Each test is implemented as:

- A PipelineRun in `.tekton/integration-test-<name>.yaml`
- A corresponding stub in `calling-pipelines/pull-request-<name>.yaml`

The following integration pipelines are currently supported:

| Test Name                  | Components Covered                                                                 |
|---------------------------|-------------------------------------------------------------------------------------|
| scheduler-routing          | llm-d-inference-scheduler, llm-d-routing-sidecar                                   |
| scheduler-autoscaler       | llm-d-inference-scheduler, inferno-autoscaler                                      |
| modelservice-kvcache-utils | llm-d-modelservice, llm-d-kv-cache-manager, llm-d-pd-utils                         |
| llm-d-stack                | llm-d, llm-d-inference-scheduler, llm-d-routing-sidecar, inferno-autoscaler, llm-d-kv-cache-manager, llm-d-pd-utils (optional) |

## How to Use in Your Repository

1. Select the appropriate integration test for your component.
2. Copy the matching stub from this directory into your repository's `.tekton/` folder.
3. Rename the file to `pull-request.yaml` if needed.
4. Adjust image tags using dynamic PR-based versions such as:  
   `quay.io/llmd/<component>:pr-$(context.pipelineRun.pullRequest.number)`
5. Commit and push your changes. The Konflux GitHub App will execute the shared test.

## Required Annotations

All PipelineRun stubs should include the following annotations:

- `pipelinesascode.tekton.dev/repo`:  
  `https://github.com/llm-d-incubation/llm-d-ci@main`

- `pipelinesascode.tekton.dev/pipelinerun`:  
  `.tekton/integration-test-<name>.yaml`

## Parameters by Test

Each integration test defines required input parameters. The following lists the expected parameters for each supported pipeline.

### scheduler-routing

- `scheduler-image`
- `sidecar-image`

### scheduler-autoscaler

- `scheduler-image`
- `autoscaler-image`

### modelservice-kvcache-utils

- `modelservice-image`
- `kv-cache-image`
- `pd-utils-image`

### llm-d-stack

- `llm-d-image`
- `scheduler-image`
- `sidecar-image`
- `autoscaler-image`
- `kv-cache-image`
- `pd-utils-image` (optional)

## Example Stubs Included

This directory contains the following example stub files:

- `pull-request-scheduler-routing.yaml`
- `pull-request-scheduler-autoscaler.yaml`
- `pull-request-modelservice-kvcache-utils.yaml`
- `pull-request-llm-d-stack.yaml`

Each file is ready to be copied and customized in downstream repositories.

## Notes

- These tests assume container images are built and pushed during each repo’s PR workflow.
- The `llm-d-ci` repository contains only integration test logic. It does not build or publish images.
- Each test runs in an ephemeral namespace and posts the result as a comment on the pull request.

## Running Tests Locally

You can invoke any of the shared integration tests locally using the helper script:

```bash
./scripts/run-integration-test.sh <test-name> [--cleanup]
```

### Arguments:
<test-name>: One of the supported test names, such as scheduler-routing, llm-d-stack, etc.
--cleanup: Optional. Deletes the temporary namespace after test completion.

### Example:
./scripts/run-integration-test.sh scheduler-routing --cleanup
This creates a temporary namespace, copies the required secret, installs shared tasks, and executes the selected integration test pipeline.

### Usage:
```bash
./scripts/run-integration-test.sh -h
```

To request a new integration pipeline or contribute updates, open a pull request or issue in the llm-d-incubation/llm-d-ci repository.
# Container registry

Creates the ECR repository with AES-256 encryption, scan-on-push, and lifecycle rules for image retention.

[Inspect the source](main.tf) · [Variables](variables.tf) · [Outputs](outputs.tf)

## Configuration

No other lab stack is required. Configure the repository name and AWS region, then inspect the plan. The deployment helper scripts are original lab references; their image-build instructions require the private application project.

See the [infrastructure guide](../README.md) for dependencies, state configuration, and operating boundaries. Application source and assets are maintained privately; the [container and CI examples](../../examples/README.md) describe their integration.

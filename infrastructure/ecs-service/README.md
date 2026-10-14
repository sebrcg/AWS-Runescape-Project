# Single-server ECS service

Runs the initial single-server task definition on Fargate using the shared network and security group.

[Inspect the source](service.tf) · [Variables](variables.tf) · [Outputs](outputs.tf)

## Configuration

Apply the shared cluster, EFS, and task-definition roots first; publish the application image before starting a task. The public export defaults desired_count to 0. Raising it starts billable compute. This service is the initial direct-access path; the worlds root provides the later NLB-backed services.

See the [infrastructure guide](../README.md) for dependencies, state configuration, and operating boundaries. Application source and assets are maintained privately; the [container and CI examples](../../examples/README.md) describe their integration.

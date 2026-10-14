# Single-server task definition

Defines the Fargate task, EFS volume mount, container health probe, CloudWatch log configuration, and optional database secret injection.

[Inspect the source](task-definition.tf) · [Variables](variables.tf) · [Outputs](outputs.tf)

## Configuration

Apply the shared cluster and EFS roots first, and supply the ECR image URL. Copy terraform.tfvars.example to your own local terraform.tfvars; real values are not included. If enable_database is true, the optional RDS stack must already exist. The Bash TCP health check has a 120-second startup period.

See the [infrastructure guide](../README.md) for dependencies, state configuration, and operating boundaries. Application source and assets are maintained privately; the [container and CI examples](../../examples/README.md) describe their integration.

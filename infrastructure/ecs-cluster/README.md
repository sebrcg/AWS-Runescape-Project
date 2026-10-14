# Network, cluster, and IAM

Creates the shared VPC, two Availability Zones of subnets, routing, task security group, ECS cluster, log group, and task/execution roles.

[Inspect the source](vpc.tf) · [Variables](variables.tf) · [Outputs](outputs.tf)

## Configuration

NAT is optional and disabled in the cost-focused lab configuration. The subnets labeled private route through the Internet Gateway when NAT is disabled, and tasks require public IPs for outbound internet access. Names and tags are used by downstream stacks to locate these resources.

See the [infrastructure guide](../README.md) for dependencies, state configuration, and operating boundaries. Application source and assets are maintained privately; the [container and CI examples](../../examples/README.md) describe their integration.

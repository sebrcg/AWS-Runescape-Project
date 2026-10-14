# Terraform infrastructure

Separate root stacks provision the lab in dependency order. They use name/tag lookups to find resources owned by other stacks; [modules/world](modules/world/) receives explicit IDs and is instantiated with `for_each`.

| Stack | Purpose | Depends on |
| --- | --- | --- |
| [ecr](ecr/) | Container registry, scan-on-push, and image lifecycle policy | AWS account |
| [ecs-cluster](ecs-cluster/) | VPC, subnets, routes, task security group, cluster, IAM roles | AWS account |
| [efs](efs/) | Encrypted filesystem, private mount targets, access point, task-role mount permissions | `ecs-cluster` |
| [ecs-task-definition](ecs-task-definition/) | Initial single-server container definition, health probe, EFS mount, logs | `ecs-cluster`, `efs`, an image in ECR |
| [ecs-service](ecs-service/) | Initial single-server Fargate service | `ecs-task-definition` |
| [worlds](worlds/) | Independent worlds with isolated storage and stable TCP endpoints | `ecs-cluster`, `efs`, an image in ECR |
| [observability](observability/) | CloudWatch dashboard, metric/log alarms, SNS notifications | A selected ECS service and its log group |
| [github-oidc](github-oidc/) | GitHub Actions IAM role, scoped policies, S3 build-asset bucket | An existing GitHub OIDC provider and a Pulumi state bucket |
| [rds](rds/) | Optional MySQL hiscores database with an RDS-managed secret | `ecs-cluster`; apply before enabling database integration |

## Configuring the reference

Use Terraform 1.x and the AWS provider version specified by each stack. Authenticate to your own AWS account. Copy a stack's `terraform.tfvars.example` to a local, ignored `terraform.tfvars`, then supply its required variables.

For the multi-world path, provision `ecr`, `ecs-cluster`, and `efs` first, publish the application image, then configure `worlds` with the registry URL. The [worlds variables](worlds/variables.tf) contain the map of worlds; [outputs](worlds/outputs.tf) expose the endpoints.

```hcl
worlds = {
  world1 = { id = 1 }
  world2 = { id = 2 }
  world3 = { id = 3 }
}
desired_count = 0
```

The single-server path and the multi-world path are alternative operating configurations. Configure monitoring with the actual service and log-group names you choose. An SNS email subscription must be confirmed by its recipient.

`github-oidc` deliberately has no default repository or state bucket in this export. Supply the identity and bucket for your own environment. Its identity provider is a data source: it references an existing `token.actions.githubusercontent.com` provider instead of creating another one.

## State and operating boundaries

The exported Terraform roots do not define a remote backend. Configure your own backend if deploying them; Terraform state and local variables are excluded from this repository. The separate [Pulumi baseline](../infrastructure-pulumi/README.md) documents its S3 state backend.

Zero desired tasks avoid Fargate compute charges, but per-world NLBs, EFS storage, observability, and optional RDS are still billable. The lab's original permissive task ingress and mutable `latest` image tag are visible in the source; narrowing ingress and deploying by digest remain improvements.

The exported `efs` task-role policy is conditioned on the single-server access point. Running the later world module requires IAM mount permissions matching its per-world access points in the target environment; this archive does not provide a turnkey multi-world apply.

The application and build cache are not distributed here. See the [container/CI reference guide](../examples/README.md) for those dependencies.

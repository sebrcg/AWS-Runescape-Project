# Pulumi Python: initial single-server baseline

This program recreates the original ECR, VPC/networking, IAM, ECS cluster, task definition, and service architecture in Python. It was built to compare direct resource references in Pulumi with separate Terraform roots that discover their dependencies by name.

It represents an earlier milestone. The later Terraform EFS, multi-world NLB, observability, and optional database work is not reproduced in this program.

## Files

- [__main__.py](__main__.py): resource definitions and exported outputs.
- [Pulumi.dev.yaml.example](Pulumi.dev.yaml.example): non-secret example configuration with zero desired tasks.
- [bootstrap-state-backend.sh](bootstrap-state-backend.sh) and [PowerShell equivalent](bootstrap-state-backend.ps1): create a private, encrypted, versioned S3 state bucket in the caller's account.
- [CI preview example](../examples/ci/pulumi-preview.yml.example): OIDC authentication, S3 state, and pull-request preview comments.

## Setup in your own environment

Use Python 3 and the Pulumi CLI. AWS credentials are required for both preview and deployment because the program queries account identity and Availability Zones.

```bash
cd infrastructure-pulumi
python3 -m venv venv
./venv/bin/python -m pip install -r requirements.txt
cp Pulumi.dev.yaml.example Pulumi.dev.yaml
```

The bootstrap scripts create AWS resources; inspect their configuration before using them. Select the S3 backend they create with `pulumi login s3://YOUR_STATE_BUCKET`, initialize/select the `dev` stack, and provide your own secrets-provider passphrase through `PULUMI_CONFIG_PASSPHRASE`.

`pulumi preview` reads AWS and previews changes. `pulumi up` creates or updates resources. The application image must be published separately before running an ECS task. No application source, build assets, state, or stack encryption metadata is included in this public repository.

For this export, the desired-count fallback was adjusted to honor `0`, and the old `netstat` health check was replaced with the same Bash TCP probe used in the Terraform lab. These changes have not been applied to a live AWS stack as part of publishing this showcase.

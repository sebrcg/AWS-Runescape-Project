# Container and CI reference examples

These files document the pipeline used with the private application. They are not active GitHub Actions workflows in this showcase.

| Example | What it demonstrates |
| --- | --- |
| [container/Dockerfile](container/Dockerfile) | A Gradle build stage, a separate Java runtime stage, baked-in static assets, and an EFS-compatible dynamic-data path |
| [ci/deploy.yml.example](ci/deploy.yml.example) | Manual workflow dispatch, OIDC role assumption, S3 build-asset download, ECR publishing, and an ECS service rollout |
| [ci/pulumi-preview.yml.example](ci/pulumi-preview.yml.example) | Pull-request previews using GitHub OIDC and a self-managed S3 Pulumi state backend |

## Original deployment flow

```text
GitHub OIDC → temporary AWS credentials → ECR login → S3 cache download
           → Docker build → push commit-SHA and latest tags → ECS update-service
```

The deployment example requires `AWS_DEPLOY_ROLE_ARN` as a repository secret. It also expects the original Gradle wrapper/build files, application source, `data/resource`, and a `cache.tar.gz` in the configured S3 asset bucket. Those application files are intentionally absent here.

The preview example requires `AWS_PREVIEW_ROLE_ARN` and `PULUMI_CONFIG_PASSPHRASE` as secrets, `PULUMI_STATE_URL` as a repository variable, and a locally configured Pulumi stack. Use a privately generated passphrase; no passphrase is supplied in this repository.

To adapt an example to a complete application repository, configure its AWS resources and repository-scoped IAM trust, then place the workflow in that repository's `.github/workflows/` directory. Copying the showcase does not grant it AWS access.

Images carry commit-SHA tags for source traceability. The reference ECS task definitions still use `latest`, and deployment forces a fresh ECS rollout. Pinning the deployed task definition to a digest is future work; the existing workflow does not automate that step or a rollback.

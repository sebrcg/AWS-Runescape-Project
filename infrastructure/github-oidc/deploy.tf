# --- CI/CD deploy permissions for GitHub Actions ---
#
# Widens the OIDC role so the deploy workflow can (1) push the freshly built
# image to ECR and (2) roll the ECS service onto it. Kept as a SEPARATE policy
# from the pulumi-preview one so each concern stays legible and independently
# auditable. Everything here is least-privilege: scoped to our one ECR repo and
# our one cluster's services, not account-wide.

# Our own account id, used to build ARNs without hardcoding it in the file.
data "aws_caller_identity" "current" {}

# Look the ECR repo up by name so we can scope the push policy to exactly it.
data "aws_ecr_repository" "server" {
  name = var.ecr_repository_name
}

# Bucket holding large build assets (the ~246 MB game cache) that are too big to
# commit to git. The deploy workflow pulls the cache from here before it runs
# `docker build`. Private by default; only the CI role can read it (below).
resource "aws_s3_bucket" "build_assets" {
  bucket = "rsps-build-assets-${data.aws_caller_identity.current.account_id}"
}

resource "aws_iam_role_policy" "deploy" {
  name = "${var.role_name}-deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # The ECR login token is an account-level call, so it MUST be on "*".
        # It grants no access to any repo by itself — it just mints a docker
        # login. The push permissions below are what's actually scoped.
        Sid      = "EcrAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        # Upload layers and put the image — scoped to just the server repo.
        Sid    = "EcrPushToServerRepo"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = data.aws_ecr_repository.server.arn
      },
      {
        # Force a new deployment so ECS pulls the new image. Scoped to services
        # in OUR cluster only — CI can't touch services anywhere else.
        Sid    = "EcsRollService"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${var.cluster_name}/*"
      },
      {
        # Let CI pull the game-cache tarball from the build-assets bucket before
        # building. Read-only, scoped to just this bucket's objects.
        Sid      = "ReadBuildAssets"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.build_assets.arn}/*"
      }
    ]
  })
}

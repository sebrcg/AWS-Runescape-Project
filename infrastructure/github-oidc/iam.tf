# IAM role that GitHub Actions assumes via OIDC — no long-lived access keys.
# The trust policy says: "a GitHub Actions OIDC token is allowed to assume this
# role ONLY if it was issued for this repository and its audience is AWS STS."
resource "aws_iam_role" "github_actions" {
  name        = var.role_name
  description = "Assumed by GitHub Actions in ${var.github_repository} via OIDC (pulumi preview)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          # aud must be the AWS STS audience (set by configure-aws-credentials).
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          # sub scopes WHICH repo/ref may assume the role. This is the security
          # boundary — without it, any GitHub repo could assume this role.
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:${var.subject_claim}"
          }
        }
      }
    ]
  })

  tags = {
    Name      = var.role_name
    Component = "CI-CD"
  }
}

# Least-privilege policy for `pulumi preview`: read-only describe/get/list to
# compute the plan, plus read/write to the Pulumi state bucket. This role can
# NOT create/modify/delete real infrastructure — preview only reads. Widen this
# when CI starts actually deploying (roadmap Step 3).
resource "aws_iam_role_policy" "preview" {
  name = "${var.role_name}-preview"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadOnlyForPlan"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "ec2:Describe*",
          "ecs:Describe*",
          "ecs:List*",
          "ecr:Describe*",
          "ecr:List*",
          "ecr:GetLifecyclePolicy",
          "ecr:GetRepositoryPolicy",
          "iam:GetRole",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "logs:DescribeLogGroups",
          "logs:ListTagsForResource"
        ]
        Resource = "*"
      },
      {
        Sid      = "PulumiStateBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::${var.pulumi_state_bucket}"
      },
      {
        Sid      = "PulumiStateObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::${var.pulumi_state_bucket}/*"
      }
    ]
  })
}

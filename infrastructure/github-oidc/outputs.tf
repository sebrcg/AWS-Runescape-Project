output "role_arn" {
  description = "ARN of the GitHub Actions OIDC role — use as role-to-assume in the workflow"
  value       = aws_iam_role.github_actions.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.github_actions.name
}

output "next_steps" {
  description = "How to switch the workflow over to this role"
  value       = <<-EOT

    Role created: ${aws_iam_role.github_actions.arn}

    1. In .github/workflows/pulumi-preview.yml:
       - add  id-token: write  under permissions
       - in the configure-aws-credentials step, replace the access-key inputs with:
           role-to-assume: ${aws_iam_role.github_actions.arn}

    2. Delete the now-unused repo secrets:
           AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
       (keep PULUMI_CONFIG_PASSPHRASE)
  EOT
}

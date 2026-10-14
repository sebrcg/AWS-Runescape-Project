# Bootstrap the Pulumi remote-state S3 bucket (run once).
#
# Pulumi (like Terraform) can't store the state for the bucket that holds its
# own state, so the state bucket is created out-of-band here with the AWS CLI.
# The bucket is versioned (so you can roll back a bad state write), encrypted,
# and fully private.
#
# Usage:  .\bootstrap-state-backend.ps1
#
# Safe to re-run: every step is idempotent.

$ErrorActionPreference = "Stop"

$Region     = "us-east-1"
$AccountId  = (aws sts get-caller-identity --query Account --output text)
$BucketName = "rsps-pulumi-state-$AccountId"

Write-Host "Account:  $AccountId"
Write-Host "Bucket:   $BucketName"
Write-Host "Region:   $Region"
Write-Host ""

# 1) Create the bucket (us-east-1 must NOT pass a LocationConstraint).
$exists = $false
try { aws s3api head-bucket --bucket $BucketName 2>$null; if ($?) { $exists = $true } } catch {}
if ($exists) {
    Write-Host "Bucket already exists, skipping create."
} else {
    aws s3api create-bucket --bucket $BucketName --region $Region | Out-Null
    Write-Host "Created bucket."
}

# 2) Block all public access.
aws s3api put-public-access-block --bucket $BucketName --public-access-block-configuration `
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" | Out-Null
Write-Host "Public access blocked."

# 3) Enable versioning.
aws s3api put-bucket-versioning --bucket $BucketName `
    --versioning-configuration "Status=Enabled" | Out-Null
Write-Host "Versioning enabled."

# 4) Default server-side encryption (AES256).
aws s3api put-bucket-encryption --bucket $BucketName --server-side-encryption-configuration `
    '{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"AES256\"}}]}' | Out-Null
Write-Host "Encryption enabled."

Write-Host ""
Write-Host "Done. Point Pulumi at it with:"
Write-Host "    pulumi login s3://$BucketName"

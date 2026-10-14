#!/usr/bin/env bash
# Bootstrap the Pulumi remote-state S3 bucket (run once).
#
# Pulumi (like Terraform) can't store the state for the bucket that holds its
# own state, so the state bucket is created out-of-band here with the AWS CLI.
# The bucket is versioned (roll back a bad state write), encrypted, and private.
#
# Usage:  ./bootstrap-state-backend.sh
# Safe to re-run: every step is idempotent.

set -euo pipefail

REGION="us-east-1"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="rsps-pulumi-state-${ACCOUNT_ID}"

echo "Account: ${ACCOUNT_ID}"
echo "Bucket:  ${BUCKET}"
echo "Region:  ${REGION}"
echo

# 1) Create the bucket (us-east-1 must NOT pass a LocationConstraint).
if aws s3api head-bucket --bucket "${BUCKET}" 2>/dev/null; then
  echo "Bucket already exists, skipping create."
else
  aws s3api create-bucket --bucket "${BUCKET}" --region "${REGION}" >/dev/null
  echo "Created bucket."
fi

# 2) Block all public access.
aws s3api put-public-access-block --bucket "${BUCKET}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true >/dev/null
echo "Public access blocked."

# 3) Enable versioning.
aws s3api put-bucket-versioning --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled >/dev/null
echo "Versioning enabled."

# 4) Default server-side encryption (AES256).
aws s3api put-bucket-encryption --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' >/dev/null
echo "Encryption enabled."

echo
echo "Done. Point Pulumi at it with:"
echo "    pulumi login s3://${BUCKET}"

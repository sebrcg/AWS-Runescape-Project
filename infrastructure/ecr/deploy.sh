#!/bin/bash
set -e

echo "🚀 RSPS Server - ECR Repository Deployment"
echo "=========================================="
echo ""

# Check prerequisites
echo "✓ Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed. Please install from https://www.terraform.io/downloads"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install from https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi

echo "✓ All prerequisites met!"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "⚠️  terraform.tfvars not found. Creating from example..."
    cp terraform.tfvars.example terraform.tfvars
    echo "✓ Created terraform.tfvars - please review and customize if needed"
    echo ""
fi

# Initialize Terraform
echo "📦 Initializing Terraform..."
terraform init
echo ""

# Plan
echo "📋 Planning infrastructure changes..."
terraform plan -out=tfplan
echo ""

# Ask for confirmation
read -p "🤔 Do you want to apply these changes? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "❌ Deployment cancelled."
    exit 0
fi

# Apply
echo "🔨 Applying infrastructure..."
terraform apply tfplan
rm -f tfplan
echo ""

# Display outputs
echo "✅ ECR Repository created successfully!"
echo ""
echo "📊 Repository Details:"
terraform output -json | jq -r '
  "Repository URL:  \(.repository_url.value)",
  "Repository Name: \(.repository_name.value)",
  "Registry ID:     \(.registry_id.value)",
  "Repository ARN:  \(.repository_arn.value)"
'
echo ""

# Show next steps
echo "🎯 Next Steps:"
echo "1. Authenticate Docker:"
echo "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin \$(terraform output -raw repository_url | cut -d'/' -f1)"
echo ""
echo "2. Build and tag your image:"
echo "   docker build -t rsps-server:latest /path/to/private-application"
echo "   docker tag rsps-server:latest \$(terraform output -raw repository_url):latest"
echo ""
echo "3. Push to ECR:"
echo "   docker push \$(terraform output -raw repository_url):latest"
echo ""

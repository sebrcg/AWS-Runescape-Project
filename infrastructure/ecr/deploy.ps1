# PowerShell deployment script for ECR repository
$ErrorActionPreference = "Stop"

Write-Host "🚀 RSPS Server - ECR Repository Deployment" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
Write-Host "✓ Checking prerequisites..." -ForegroundColor Green

# Check Terraform
if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Terraform is not installed. Please install from https://www.terraform.io/downloads" -ForegroundColor Red
    exit 1
}

# Check AWS CLI
if (!(Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed. Please install from https://aws.amazon.com/cli/" -ForegroundColor Red
    exit 1
}

# Check AWS credentials
try {
    aws sts get-caller-identity | Out-Null
} catch {
    Write-Host "❌ AWS credentials not configured. Run 'aws configure' first." -ForegroundColor Red
    exit 1
}

Write-Host "✓ All prerequisites met!" -ForegroundColor Green
Write-Host ""

# Check if terraform.tfvars exists
if (!(Test-Path "terraform.tfvars")) {
    Write-Host "⚠️  terraform.tfvars not found. Creating from example..." -ForegroundColor Yellow
    Copy-Item "terraform.tfvars.example" "terraform.tfvars"
    Write-Host "✓ Created terraform.tfvars - please review and customize if needed" -ForegroundColor Green
    Write-Host ""
}

# Initialize Terraform
Write-Host "📦 Initializing Terraform..." -ForegroundColor Cyan
terraform init
Write-Host ""

# Plan
Write-Host "📋 Planning infrastructure changes..." -ForegroundColor Cyan
terraform plan -out=tfplan
Write-Host ""

# Ask for confirmation
$confirm = Read-Host "🤔 Do you want to apply these changes? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "❌ Deployment cancelled." -ForegroundColor Red
    exit 0
}

# Apply
Write-Host "🔨 Applying infrastructure..." -ForegroundColor Cyan
terraform apply tfplan
Remove-Item -Path tfplan -ErrorAction SilentlyContinue
Write-Host ""

# Display outputs
Write-Host "✅ ECR Repository created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Repository Details:" -ForegroundColor Cyan

$repoUrl = terraform output -raw repository_url
$repoName = terraform output -raw repository_name
$registryId = terraform output -raw registry_id
$repoArn = terraform output -raw repository_arn

Write-Host "Repository URL:  $repoUrl" -ForegroundColor White
Write-Host "Repository Name: $repoName" -ForegroundColor White
Write-Host "Registry ID:     $registryId" -ForegroundColor White
Write-Host "Repository ARN:  $repoArn" -ForegroundColor White
Write-Host ""

# Show next steps
Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
Write-Host "1. Authenticate Docker:" -ForegroundColor White
$registryDomain = $repoUrl -replace '/.*', ''
Write-Host "   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $registryDomain" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Build and tag your image:" -ForegroundColor White
Write-Host "   docker build -t rsps-server:latest /path/to/private-application" -ForegroundColor Gray
Write-Host "   docker tag rsps-server:latest ${repoUrl}:latest" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Push to ECR:" -ForegroundColor White
Write-Host "   docker push ${repoUrl}:latest" -ForegroundColor Gray
Write-Host ""

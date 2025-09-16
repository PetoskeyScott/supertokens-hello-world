# Development/Testing Deployment Script
# This script is optimized for fast iteration during development
# Uses GitHub clone instead of Docker registry for speed
# 
# Usage:
#   .\deploy-devtest.ps1 0.0.0.0          # Create new EC2 instance
#   .\deploy-devtest.ps1 1.2.3.4          # Use existing EC2 instance

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP
)

# Check if AWS CLI is installed and configured
Write-Host "Checking AWS CLI configuration..." -ForegroundColor Yellow
aws sts get-caller-identity 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "AWS CLI is not configured or you are not authenticated. Please run 'aws configure' first."
    exit 1
}

Write-Host "AWS CLI is configured correctly" -ForegroundColor Green

# Determine if we're creating a new instance or using existing one
$CREATE_NEW_INSTANCE = $EC2_PUBLIC_IP -eq "0.0.0.0"

if ($CREATE_NEW_INSTANCE) {
    Write-Host "Creating new EC2 instance..." -ForegroundColor Green
} else {
    Write-Host "Using existing EC2 instance: $EC2_PUBLIC_IP" -ForegroundColor Green
}

# Get GitHub repository URL
$GITHUB_REPO_URL = "https://github.com/PetoskeyScott/supertokens-hello-world.git"


# Create deployment directory (reuse existing)
$DEPLOY_DIR = "deployment-devtest"
if (Test-Path $DEPLOY_DIR) {
    Remove-Item -Path $DEPLOY_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null

Write-Host "Created deployment directory: $DEPLOY_DIR" -ForegroundColor Green

# Get or create passwords (only generate new ones for new instances)
if ($CREATE_NEW_INSTANCE) {
    Write-Host "🆕 Creating new instance - generating fresh passwords" -ForegroundColor Yellow
    # Generate secure passwords (avoiding special characters that break PostgreSQL URIs)
    $SUPERTOKENS_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    $APP_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    
    # Save passwords for future incremental deployments
    $passwords = @{
        POSTGRES_ROOT_PASSWORD = $SUPERTOKENS_PASSWORD
        SUPERTOKENS_PASSWORD = $SUPERTOKENS_PASSWORD
        APP_PASSWORD = $APP_PASSWORD
        CREATED_DATE = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    $passwords | ConvertTo-Json | Out-File -FilePath "deployment-passwords.json" -Encoding UTF8
    Write-Host "💾 Saved passwords for future incremental deployments" -ForegroundColor Green
} else {
    Write-Host "🔄 Using existing instance - retrieving saved passwords" -ForegroundColor Yellow
    if (Test-Path "deployment-passwords.json") {
        $savedPasswords = Get-Content "deployment-passwords.json" | ConvertFrom-Json
        $SUPERTOKENS_PASSWORD = $savedPasswords.SUPERTOKENS_PASSWORD
        $APP_PASSWORD = $savedPasswords.APP_PASSWORD
        Write-Host "✅ Retrieved existing passwords (created: $($savedPasswords.CREATED_DATE))" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No saved passwords found. Generating new ones..." -ForegroundColor Yellow
        $SUPERTOKENS_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        $APP_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        
        # Save the new passwords
        $passwords = @{
            POSTGRES_ROOT_PASSWORD = $SUPERTOKENS_PASSWORD
            SUPERTOKENS_PASSWORD = $SUPERTOKENS_PASSWORD
            APP_PASSWORD = $APP_PASSWORD
            CREATED_DATE = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $passwords | ConvertTo-Json | Out-File -FilePath "deployment-passwords.json" -Encoding UTF8
    }
}

# Create production environment file
$envContent = @"
# Development/Testing Environment Variables
POSTGRES_ROOT_PASSWORD=$SUPERTOKENS_PASSWORD
SUPERTOKENS_PASSWORD=$SUPERTOKENS_PASSWORD
APP_PASSWORD=$APP_PASSWORD

# Frontend configuration (will be updated with actual Elastic IP after deployment)
FRONTEND_URL=http://PLACEHOLDER_IP:3000
API_DOMAIN=http://PLACEHOLDER_IP:3001
WEBSITE_DOMAIN=http://PLACEHOLDER_IP:3000
SUPERTOKENS_CONNECTION_URI=http://PLACEHOLDER_IP:3567
"@

Write-Host "Generated passwords:" -ForegroundColor Yellow
Write-Host "POSTGRES_ROOT_PASSWORD: $SUPERTOKENS_PASSWORD" -ForegroundColor Cyan
Write-Host "SUPERTOKENS_PASSWORD: $SUPERTOKENS_PASSWORD" -ForegroundColor Cyan
Write-Host "APP_PASSWORD: $APP_PASSWORD" -ForegroundColor Cyan
Write-Host "SUPERTOKENS_CONNECTION_URI: $SUPERTOKENS_CONNECTION_URI" -ForegroundColor Cyan

$envContent | Out-File -FilePath "$DEPLOY_DIR\.env.production" -Encoding UTF8

Write-Host "Created production environment file" -ForegroundColor Green


# Only create Terraform configuration if creating new instance
if ($CREATE_NEW_INSTANCE) {
    # Create Terraform configuration
$terraformContent = @"
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Use default VPC and subnet to avoid VPC limit issues
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for EC2 instance
resource "aws_security_group" "supertokens_sg" {
  name_prefix = "supertokens-sg-"
  description = "Security group for SuperTokens application"

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access for frontend
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access for backend API
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SuperTokens core access
  ingress {
    from_port   = 3567
    to_port     = 3567
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # PostgreSQL access (optional, for direct database access)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "supertokens-security-group"
  }
}

# Elastic IP
resource "aws_eip" "supertokens_eip" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name = "supertokens-eip"
  }
}

# EC2 instance
resource "aws_instance" "main" {
  ami           = "ami-0c7217cdde317cfec"  # Ubuntu 22.04 LTS
  instance_type = "t3.small"
  key_name      = "supertokens-key"
  vpc_security_group_ids = [aws_security_group.supertokens_sg.id]
  subnet_id     = data.aws_subnets.default.ids[0]

  user_data = <<-EOF
#!/bin/bash
apt update -y
apt install -y docker.io git

# Start Docker service
systemctl start docker
systemctl enable docker
usermod -a -G docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create application directory
mkdir -p /home/ubuntu/supertokens-hello-world
chown ubuntu:ubuntu /home/ubuntu/supertokens-hello-world

# Clone the repository
cd /home/ubuntu
git clone $GITHUB_REPO_URL
chown -R ubuntu:ubuntu supertokens-hello-world

# Create systemd service for auto-start
cat > /etc/systemd/system/supertokens.service << 'EOL'
[Unit]
Description=SuperTokens Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/supertokens-hello-world
ExecStart=/usr/bin/docker-compose -f docker-compose.dev.yml up -d --force-recreate
ExecStop=/usr/bin/docker-compose -f docker-compose.dev.yml down
User=ubuntu
Group=ubuntu

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable supertokens.service
EOF

  tags = {
    Name = "supertokens-instance"
  }
}

output "public_ip" {
  value = aws_eip.supertokens_eip.public_ip
}

output "instance_id" {
  value = aws_instance.main.id
}
"@

$terraformContent | Out-File -FilePath "$DEPLOY_DIR\main.tf" -Encoding UTF8

    Write-Host "Created Terraform configuration" -ForegroundColor Green
} else {
    Write-Host "Skipping Terraform configuration (using existing instance)" -ForegroundColor Yellow
}

# Create quick deployment script
$quickDeployContent = @"
# Quick Development/Testing Deployment Script
# This script deploys the application to EC2 using GitHub clone

param(
    [Parameter(Mandatory=`$true)]
    [string]`$EC2_PUBLIC_IP,
    [Parameter(Mandatory=`$true)]
    [string]`$GITHUB_REPO_URL
)

Write-Host "Starting development/testing deployment to `$EC2_PUBLIC_IP" -ForegroundColor Green

# Check if this is a new instance or existing one
`$IS_NEW_INSTANCE = `$EC2_PUBLIC_IP -eq "0.0.0.0"

if (`$IS_NEW_INSTANCE) {
    # Wait for new instance to be ready
    Write-Host "Waiting for new EC2 instance to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
} else {
    # For existing instance, just wait a moment
    Write-Host "Using existing EC2 instance..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# Test SSH connection
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "ubuntu@`${EC2_PUBLIC_IP}" "echo 'SSH connection successful'"
if (`$LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed. Please check if the instance is ready and the key is correct."
    exit 1
}

Write-Host "SSH connection successful" -ForegroundColor Green

# For existing instances, ensure repository is cloned and up to date
if (-not `$IS_NEW_INSTANCE) {
    Write-Host "Setting up repository on existing instance..." -ForegroundColor Yellow
    
    # Check if repository exists and clone/update it
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@`${EC2_PUBLIC_IP}" "if [ ! -d '/home/ubuntu/supertokens-hello-world' ]; then cd /home/ubuntu && git clone $GITHUB_REPO_URL; else cd /home/ubuntu/supertokens-hello-world && git stash && git pull; fi"
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "Repository setup/updated successfully" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to setup/update repository" -ForegroundColor Yellow
    }
    
    # Ensure Docker Compose is installed
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@`${EC2_PUBLIC_IP}" "which docker-compose > /dev/null || (sudo curl -L 'https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-Linux-x86_64' -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose)"
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "Docker Compose verified/installed" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to install Docker Compose" -ForegroundColor Yellow
    }
}

# Upload environment file
Write-Host "Uploading environment configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no ".env.production" "ubuntu@`${EC2_PUBLIC_IP}:/home/ubuntu/supertokens-hello-world/.env"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Environment file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload environment file" -ForegroundColor Yellow
}

# Docker Compose file comes from git pull, no need to upload
Write-Host "Docker Compose file will be used from git repository" -ForegroundColor Green

# Database initialization files come from git pull, no need to upload
Write-Host "Database initialization files will be used from git repository" -ForegroundColor Green

# Update environment file with actual IP
Write-Host "Updating environment file with actual IP..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@`${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && sed -i 's/PLACEHOLDER_IP/`${EC2_PUBLIC_IP}/g' .env"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Environment file updated successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to update environment file" -ForegroundColor Yellow
}

# Stop existing services before restarting
Write-Host "Stopping existing services..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@`${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml down 2>/dev/null || true"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Existing services stopped" -ForegroundColor Green
} else {
    Write-Host "No existing services to stop" -ForegroundColor Yellow
}

# Restart services on EC2 instance
Write-Host "Starting services on EC2 instance..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@`${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml down && docker-compose -f docker-compose.dev.yml up -d --force-recreate"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Services restarted successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to restart services" -ForegroundColor Yellow
}

Write-Host "Development/testing deployment completed!" -ForegroundColor Green
Write-Host "Frontend: http://`${EC2_PUBLIC_IP}:3000" -ForegroundColor Cyan
Write-Host "Backend API: http://`${EC2_PUBLIC_IP}:3001" -ForegroundColor Cyan
Write-Host "SuperTokens Core: http://`${EC2_PUBLIC_IP}:3567" -ForegroundColor Cyan
"@

$quickDeployContent | Out-File -FilePath "$DEPLOY_DIR\quick-deploy-devtest.ps1" -Encoding UTF8

Write-Host "Created quick deployment script" -ForegroundColor Green

# Create README for development deployment
$readmeContent = @"
# Development/Testing Deployment

This deployment is optimized for fast iteration during development.

## Two Modes:

### New Instance Mode (0.0.0.0):
- Creates new EC2 instance with Terraform
- Clones repository via user_data script
- Full setup from scratch

### Existing Instance Mode (real IP):
- Uses existing EC2 instance
- Updates repository with git pull
- Stops existing services and redeploys
- Perfect for code changes

## What it does:
- Smart detection: 0.0.0.0 = new instance, real IP = existing instance
- Builds Docker images on EC2 (faster for development)
- No Docker registry required
- Quick deployment for testing changes

## Usage:
1. **New instance**: `.\deploy-devtest.ps1 0.0.0.0`
2. **Existing instance**: `.\deploy-devtest.ps1 1.2.3.4`
3. **Then run**: `cd deployment-devtest` and follow the instructions
4. Wait for deployment to complete

## Files included:
- `.env.production` - Environment variables
- `main.tf` - Terraform configuration (new instance only)
- `quick-deploy-devtest.ps1` - Quick deployment script
- `docker-compose.prod.yml` - Docker Compose configuration
- `init-db.sql` - Database initialization

## Note:
This is for development/testing only. Use `deploy-prod.ps1` for production deployments.
"@

$readmeContent | Out-File -FilePath "$DEPLOY_DIR\README.md" -Encoding UTF8

Write-Host "Created README file" -ForegroundColor Green

Write-Host "Development/testing deployment package created in: $DEPLOY_DIR" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow

if ($CREATE_NEW_INSTANCE) {
    Write-Host "1. terraform init" -ForegroundColor White
    Write-Host "2. terraform apply" -ForegroundColor White
    Write-Host "3. .\quick-deploy-devtest.ps1 0.0.0.0 `"$GITHUB_REPO_URL`"" -ForegroundColor White
} else {
    Write-Host "1. .\quick-deploy-devtest.ps1 $EC2_PUBLIC_IP `"$GITHUB_REPO_URL`"" -ForegroundColor White
    Write-Host "   (No Terraform needed - using existing instance)" -ForegroundColor Cyan
}

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
$GITHUB_REPO_URL = Read-Host "Enter your GitHub repository URL (e.g., https://github.com/username/supertokens-hello-world.git)"
if (-not $GITHUB_REPO_URL) {
    Write-Error "GitHub repository URL is required"
    exit 1
}

# Create deployment directory with timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$DEPLOY_DIR = "deployment-devtest-$timestamp"
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null

Write-Host "Created deployment directory: $DEPLOY_DIR" -ForegroundColor Green

# Generate secure passwords
$SUPERTOKENS_PASSWORD = -join ((33..126) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$APP_PASSWORD = -join ((33..126) | Get-Random -Count 32 | ForEach-Object {[char]$_})

Write-Host "Generated secure database passwords" -ForegroundColor Green

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
"@

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
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t3.micro"
  key_name      = "supertokens-key"
  vpc_security_group_ids = [aws_security_group.supertokens_sg.id]
  subnet_id     = data.aws_subnets.default.ids[0]

  user_data = <<-EOF
#!/bin/bash
yum update -y
yum install -y docker git

# Start Docker service
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Create application directory
mkdir -p /home/ec2-user/supertokens-hello-world
chown ec2-user:ec2-user /home/ec2-user/supertokens-hello-world

# Clone the repository
cd /home/ec2-user
git clone $GITHUB_REPO_URL
chown -R ec2-user:ec2-user supertokens-hello-world

# Create systemd service for auto-start
cat > /etc/systemd/system/supertokens.service << 'EOL'
[Unit]
Description=SuperTokens Application
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/supertokens-hello-world
ExecStart=/usr/bin/docker-compose -f docker-compose.prod.yml up -d
ExecStop=/usr/bin/docker-compose -f docker-compose.prod.yml down
User=ec2-user
Group=ec2-user

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
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "ec2-user@`${EC2_PUBLIC_IP}" "echo 'SSH connection successful'"
if (`$LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed. Please check if the instance is ready and the key is correct."
    exit 1
}

Write-Host "SSH connection successful" -ForegroundColor Green

# For existing instances, ensure repository is cloned and up to date
if (-not `$IS_NEW_INSTANCE) {
    Write-Host "Setting up repository on existing instance..." -ForegroundColor Yellow
    
    # Check if repository exists and clone/update it
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${EC2_PUBLIC_IP}" "if [ ! -d '/home/ec2-user/supertokens-hello-world' ]; then cd /home/ec2-user && git clone $GITHUB_REPO_URL; else cd /home/ec2-user/supertokens-hello-world && git pull; fi"
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "Repository setup/updated successfully" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to setup/update repository" -ForegroundColor Yellow
    }
    
    # Ensure Docker Compose is installed
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${EC2_PUBLIC_IP}" "which docker-compose > /dev/null || (sudo curl -L 'https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-Linux-x86_64' -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose)"
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "Docker Compose verified/installed" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to install Docker Compose" -ForegroundColor Yellow
    }
}

# Upload environment file
Write-Host "Uploading environment configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no ".env.production" "ec2-user@`${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/.env.production"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Environment file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload environment file" -ForegroundColor Yellow
}

# Upload Docker Compose file
Write-Host "Uploading Docker Compose configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../docker-compose.dev.yml" "ec2-user@`${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/docker-compose.prod.yml"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Docker Compose file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload Docker Compose file" -ForegroundColor Yellow
}

# Upload init-db.sql file
Write-Host "Uploading database initialization file..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../init-db.sql" "ec2-user@`${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/init-db.sql"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Database initialization file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload database initialization file" -ForegroundColor Yellow
}

# Update environment file with actual IP
Write-Host "Updating environment file with actual IP..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${EC2_PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && sed -i 's/PLACEHOLDER_IP/`${EC2_PUBLIC_IP}/g' .env.production"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Environment file updated successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to update environment file" -ForegroundColor Yellow
}

# Stop existing services before restarting
Write-Host "Stopping existing services..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${EC2_PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && docker-compose -f docker-compose.prod.yml down 2>/dev/null || true"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Existing services stopped" -ForegroundColor Green
} else {
    Write-Host "No existing services to stop" -ForegroundColor Yellow
}

# Restart services on EC2 instance
Write-Host "Starting services on EC2 instance..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${EC2_PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && docker-compose -f docker-compose.prod.yml down && docker-compose -f docker-compose.prod.yml up -d"
if (`$LASTEXITCODE -eq 0) {
    Write-Host "Services restarted successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to restart services" -ForegroundColor Yellow
}

Write-Host "Development/testing deployment completed!" -ForegroundColor Green
Write-Host "Frontend: http://`$EC2_PUBLIC_IP:3000" -ForegroundColor Cyan
Write-Host "Backend API: http://`$EC2_PUBLIC_IP:3001" -ForegroundColor Cyan
Write-Host "SuperTokens Core: http://`$EC2_PUBLIC_IP:3567" -ForegroundColor Cyan
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
3. Wait for deployment to complete

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
    Write-Host "1. cd $DEPLOY_DIR" -ForegroundColor White
    Write-Host "2. terraform init" -ForegroundColor White
    Write-Host "3. terraform apply" -ForegroundColor White
    Write-Host "4. .\quick-deploy-devtest.ps1 0.0.0.0 `"$GITHUB_REPO_URL`"" -ForegroundColor White
} else {
    Write-Host "1. cd $DEPLOY_DIR" -ForegroundColor White
    Write-Host "2. .\quick-deploy-devtest.ps1 $EC2_PUBLIC_IP `"$GITHUB_REPO_URL`"" -ForegroundColor White
    Write-Host "   (No Terraform needed - using existing instance)" -ForegroundColor Cyan
}

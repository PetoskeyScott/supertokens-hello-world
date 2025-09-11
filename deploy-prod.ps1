# SuperTokens Hello World - Production Deployment Script (PowerShell)
# This script uses Docker registry for production deployments
# Usage: .\deploy-prod.ps1 <YOUR_LAPTOP_IP>

param(
    [Parameter(Mandatory=$true)]
    [string]$YOUR_LAPTOP_IP
)

# Check if AWS CLI is installed
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI is not installed. Please install it first."
    exit 1
}

# Check if you're authenticated with AWS
try {
    $caller = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "You are not authenticated with AWS. Please run 'aws configure' first."
        exit 1
    }
} catch {
    Write-Error "You are not authenticated with AWS. Please run 'aws configure' first."
    exit 1
}

Write-Host "AWS authentication verified" -ForegroundColor Green

# Create deployment directory
$DEPLOY_DIR = "deployment-prod"
if (Test-Path $DEPLOY_DIR) {
    Remove-Item -Path $DEPLOY_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null

# Generate strong passwords (avoiding special characters that break PostgreSQL URIs)
$SUPERTOKENS_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$APP_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})

Write-Host "Generated secure database passwords" -ForegroundColor Green

# Create production environment file
$envContent = @"
# Production Environment Variables
POSTGRES_ROOT_PASSWORD=$SUPERTOKENS_PASSWORD
SUPERTOKENS_PASSWORD=$SUPERTOKENS_PASSWORD
APP_PASSWORD=$APP_PASSWORD

# Docker Registry Configuration
DOCKER_REGISTRY=your-dockerhub-username

# Frontend configuration (will be updated with actual Elastic IP after deployment)
FRONTEND_URL=http://PLACEHOLDER_IP:3000
API_DOMAIN=http://PLACEHOLDER_IP:3001
WEBSITE_DOMAIN=http://PLACEHOLDER_IP:3000
"@

$envContent | Out-File -FilePath "$DEPLOY_DIR\.env.production" -Encoding UTF8

Write-Host "Created production environment file" -ForegroundColor Green

# Build and push Docker images
Write-Host "Building and pushing Docker images..." -ForegroundColor Yellow

# Check if Docker is running
try {
    docker version | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker is not running. Please start Docker Desktop and try again."
        exit 1
    }
} catch {
    Write-Error "Docker is not installed or not running. Please install Docker Desktop and try again."
    exit 1
}

# Get Docker Hub username
$DOCKER_USERNAME = Read-Host "Enter your Docker Hub username"
if (-not $DOCKER_USERNAME) {
    Write-Error "Docker Hub username is required"
    exit 1
}

# Update environment file with Docker Hub username
$envContent = $envContent -replace "your-dockerhub-username", $DOCKER_USERNAME
$envContent | Out-File -FilePath "$DEPLOY_DIR\.env.production" -Encoding UTF8

# Build backend image
Write-Host "Building backend Docker image..." -ForegroundColor Yellow
docker build -t "$DOCKER_USERNAME/supertokens-backend:latest" ./backend
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build backend Docker image"
    exit 1
}

# Build frontend image
Write-Host "Building frontend Docker image..." -ForegroundColor Yellow
docker build -t "$DOCKER_USERNAME/supertokens-frontend:latest" ./frontend
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build frontend Docker image"
    exit 1
}

# Login to Docker Hub
Write-Host "Logging into Docker Hub..." -ForegroundColor Yellow
docker login
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to login to Docker Hub"
    exit 1
}

# Push backend image
Write-Host "Pushing backend Docker image..." -ForegroundColor Yellow
docker push "$DOCKER_USERNAME/supertokens-backend:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push backend Docker image"
    exit 1
}

# Push frontend image
Write-Host "Pushing frontend Docker image..." -ForegroundColor Yellow
docker push "$DOCKER_USERNAME/supertokens-frontend:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to push frontend Docker image"
    exit 1
}

Write-Host "Docker images built and pushed successfully!" -ForegroundColor Green

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
  region = "us-east-1"  # Change this to your preferred region
}

# Use default VPC and subnet
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "default" {
  vpc_id = data.aws_vpc.default.id
  availability_zone = "us-east-1a"  # Change this to your preferred AZ
}

resource "aws_security_group" "main" {
  name        = "supertokens-sg"
  description = "Security group for SuperTokens application"
  vpc_id      = data.aws_vpc.default.id

  # SSH access from your laptop only
  ingress {
    description = "SSH from your laptop"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["$YOUR_LAPTOP_IP/32"]
  }

  # HTTP/HTTPS access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SuperTokens core port
  ingress {
    description = "SuperTokens core"
    from_port   = 3567
    to_port     = 3567
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend API port
  ingress {
    description = "Backend API"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Frontend port
  ingress {
    description = "Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "supertokens-sg"
  }
}

# Elastic IP for consistent IP address
resource "aws_eip" "main" {
  domain = "vpc"
  
  tags = {
    Name = "supertokens-eip"
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 (change for your region)
  instance_type          = "t3.small"
  key_name               = "supertokens-key"  # You'll need to create this key pair
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = data.aws_subnet.default.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Install Node.js
              curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
              source ~/.bashrc
              nvm install 18
              nvm use 18
              
              # Create application directory
              cd /home/ec2-user
              mkdir -p supertokens-hello-world
              cd supertokens-hello-world
              
              # Wait for files to be uploaded by deployment script
              echo "Waiting for application files to be uploaded..."
              sleep 30
              
              # Start services (files will be uploaded by deployment script)
              docker-compose -f docker-compose.prod.yml up -d
              EOF

  tags = {
    Name = "supertokens-server"
  }

  depends_on = []
}

# Associate Elastic IP with EC2 instance
resource "aws_eip_association" "main" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main.id
}

# Output the public IP (Elastic IP)
output "public_ip" {
  value = aws_eip.main.public_ip
}

output "instance_id" {
  value = aws_instance.main.id
}
"@

$terraformContent | Out-File -FilePath "$DEPLOY_DIR\main.tf" -Encoding UTF8

Write-Host "Created Terraform configuration" -ForegroundColor Green

# Create deployment instructions
$instructionsContent = @"
# Deployment Instructions

## Prerequisites
1. AWS CLI installed and configured
2. Terraform installed (version >= 1.0)
3. SSH key pair will be created automatically

## Steps to Deploy

### 1. Deploy Infrastructure
```bash
cd $DEPLOY_DIR
.\quick-deploy.ps1
```

The script will automatically:
- Create an SSH key pair in AWS (if it doesn't exist)
- Initialize Terraform
- Deploy the infrastructure
- Display connection information

### 3. Wait for Instance to be Ready
The instance will take a few minutes to:
- Install Docker and Docker Compose
- Clone your repository
- Start all services

### 4. Verify Deployment
```bash
# Get the public IP
terraform output public_ip

# SSH into the instance
ssh -i ../supertokens-key.pem ec2-user@<PUBLIC_IP>

# Check services
docker ps
docker-compose -f docker-compose.prod.yml ps
```

### 5. Access Your Application
- Frontend: http://<PUBLIC_IP>:3000
- Backend API: http://<PUBLIC_IP>:3001
- SuperTokens Core: http://<PUBLIC_IP>:3567

## Destroy Infrastructure
```bash
terraform destroy
```

## Environment Variables
The following environment variables are automatically generated:
- POSTGRES_ROOT_PASSWORD: $SUPERTOKENS_PASSWORD
- SUPERTOKENS_PASSWORD: $SUPERTOKENS_PASSWORD
- APP_PASSWORD: $APP_PASSWORD

## Security Notes
- SSH access is restricted to your laptop IP: $YOUR_LAPTOP_IP
- Database passwords are randomly generated
- All services run in Docker containers
- Services automatically restart on reboot
- Uses Elastic IP for consistent IP address across deployments
"@

$instructionsContent | Out-File -FilePath "$DEPLOY_DIR\DEPLOYMENT_INSTRUCTIONS.md" -Encoding UTF8

Write-Host "Created deployment instructions" -ForegroundColor Green

# Create a simple deployment script
$quickDeployContent = @"
# Quick deployment script for SuperTokens Hello World
Write-Host "Quick deployment starting..." -ForegroundColor Green

# Create SSH key pair if it doesn't exist
Write-Host "Creating SSH key pair..." -ForegroundColor Yellow
if (-not (Test-Path "../supertokens-key.pem")) {
    # Check if key already exists in AWS
    try {
        `$keyExists = aws ec2 describe-key-pairs --key-names supertokens-key --query 'KeyPairs[0].KeyName' --output text 2>&1
        if (`$LASTEXITCODE -eq 0 -and `$keyExists -eq "supertokens-key") {
            Write-Host "SSH key pair already exists in AWS, downloading it..." -ForegroundColor Yellow
            # Delete the existing key and recreate to get the private key material
            aws ec2 delete-key-pair --key-name supertokens-key
            `$keyMaterial = aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text
            if (`$LASTEXITCODE -ne 0) {
                Write-Host "Failed to download existing SSH key pair!" -ForegroundColor Red
                exit 1
            }
            # Ensure proper SSH key format with line endings
            `$keyMaterial = `$keyMaterial.Trim()
            if (-not `$keyMaterial.StartsWith("-----BEGIN")) {
                Write-Host "Warning: SSH key format may be incorrect" -ForegroundColor Yellow
            }
            `$keyMaterial | Out-File -FilePath "../supertokens-key.pem" -Encoding ASCII
            # Set proper permissions for SSH key (Windows equivalent of chmod 600)
            icacls "../supertokens-key.pem" /inheritance:r /grant:r "$env:USERNAME:(F)" /remove "Everyone" 2>&1 | Out-Null
            Write-Host "Existing SSH key pair downloaded successfully" -ForegroundColor Green
        } else {
            Write-Host "Creating new SSH key pair in AWS..." -ForegroundColor Yellow
            `$keyMaterial = aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text
            if (`$LASTEXITCODE -ne 0) {
                Write-Host "Failed to create SSH key pair!" -ForegroundColor Red
                exit 1
            }
            # Ensure proper SSH key format with line endings
            `$keyMaterial = `$keyMaterial.Trim()
            if (-not `$keyMaterial.StartsWith("-----BEGIN")) {
                Write-Host "Warning: SSH key format may be incorrect" -ForegroundColor Yellow
            }
            `$keyMaterial | Out-File -FilePath "../supertokens-key.pem" -Encoding ASCII
            # Set proper permissions for SSH key (Windows equivalent of chmod 600)
            icacls "../supertokens-key.pem" /inheritance:r /grant:r "$env:USERNAME:(F)" /remove "Everyone" 2>&1 | Out-Null
            Write-Host "SSH key pair created successfully" -ForegroundColor Green
        }
    } catch {
        Write-Host "Creating new SSH key pair in AWS..." -ForegroundColor Yellow
        `$keyMaterial = aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text
        if (`$LASTEXITCODE -ne 0) {
            Write-Host "Failed to create SSH key pair!" -ForegroundColor Red
            exit 1
        }
        # Ensure proper SSH key format with line endings
        `$keyMaterial = `$keyMaterial.Trim()
        if (-not `$keyMaterial.StartsWith("-----BEGIN")) {
            Write-Host "Warning: SSH key format may be incorrect" -ForegroundColor Yellow
        }
        `$keyMaterial | Out-File -FilePath "../supertokens-key.pem" -Encoding ASCII
        # Set proper permissions for SSH key (Windows equivalent of chmod 600)
        icacls "../supertokens-key.pem" /inheritance:r /grant:r "$env:USERNAME:(F)" /remove "Everyone" 2>&1 | Out-Null
        Write-Host "SSH key pair created successfully" -ForegroundColor Green
    }
} else {
    Write-Host "SSH key pair already exists locally" -ForegroundColor Green
}

# Verify SSH key format
Write-Host "Verifying SSH key format..." -ForegroundColor Yellow
if (Test-Path "../supertokens-key.pem") {
    `$keyContent = Get-Content "../supertokens-key.pem" -Raw
    if (`$keyContent -match "-----BEGIN.*PRIVATE KEY-----" -and `$keyContent -match "-----END.*PRIVATE KEY-----") {
        Write-Host "SSH key format is valid" -ForegroundColor Green
    } else {
        Write-Host "SSH key format is invalid! Regenerating..." -ForegroundColor Red
        Remove-Item "../supertokens-key.pem" -Force
        # Delete existing key from AWS first, then regenerate
        aws ec2 delete-key-pair --key-name supertokens-key 2>&1 | Out-Null
        `$keyMaterial = aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text
        if (`$LASTEXITCODE -eq 0) {
            `$keyMaterial.Trim() | Out-File -FilePath "../supertokens-key.pem" -Encoding ASCII
            icacls "../supertokens-key.pem" /inheritance:r /grant:r "$env:USERNAME:(F)" /remove "Everyone" 2>&1 | Out-Null
            Write-Host "SSH key regenerated successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to regenerate SSH key!" -ForegroundColor Red
            exit 1
        }
    }
} else {
    Write-Host "SSH key file not found!" -ForegroundColor Red
    exit 1
}

# Initialize Terraform
Write-Host "Initializing the backend..." -ForegroundColor Yellow
terraform init
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Terraform init failed!" -ForegroundColor Red
    exit 1
}

# Plan deployment
Write-Host "Planning deployment..." -ForegroundColor Yellow
terraform plan
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Terraform plan failed!" -ForegroundColor Red
    exit 1
}

# Apply configuration
Write-Host "Applying configuration..." -ForegroundColor Yellow
terraform apply -auto-approve
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Terraform apply failed!" -ForegroundColor Red
    exit 1
}

# Get the public IP only after successful deployment
Write-Host "Getting deployment information..." -ForegroundColor Yellow
`$PUBLIC_IP = terraform output -raw public_ip
if (`$LASTEXITCODE -ne 0) {
    Write-Host "Failed to get public IP from Terraform output!" -ForegroundColor Red
    exit 1
}

# Update environment file with actual IP
Write-Host "Updating environment file with actual IP address..." -ForegroundColor Yellow
`$envFile = ".env"
Write-Host "Looking for environment file: `$envFile" -ForegroundColor Yellow
Write-Host "Current directory: `$(Get-Location)" -ForegroundColor Yellow
Write-Host "Files in current directory:" -ForegroundColor Yellow
Get-ChildItem | ForEach-Object { Write-Host "  `$(`$_.Name)" -ForegroundColor White }
if (Test-Path `$envFile) {
    `$envContent = Get-Content `$envFile -Raw
    `$envContent = `$envContent -replace "PLACEHOLDER_IP", `$PUBLIC_IP
    `$envContent | Out-File -FilePath `$envFile -Encoding UTF8
    Write-Host "Environment file updated with IP: `$PUBLIC_IP" -ForegroundColor Green
    
    # Upload necessary files to EC2 instance
    Write-Host "Uploading application files to EC2 instance..." -ForegroundColor Yellow
    
    # Upload environment file
    scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no `$envFile "ec2-user@`${PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/.env"
    if (`$LASTEXITCODE -eq 0) {
        Write-Host "Environment file uploaded successfully" -ForegroundColor Green
        
        # Upload Docker Compose file
        Write-Host "Uploading Docker Compose file..." -ForegroundColor Yellow
        scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../docker-compose.prod.yml" "ec2-user@`${PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/docker-compose.prod.yml"
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "Docker Compose file uploaded successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: Failed to upload Docker Compose file" -ForegroundColor Yellow
        }
        
        # Upload init-db.sql file
        Write-Host "Uploading database initialization file..." -ForegroundColor Yellow
        scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../init-db.sql" "ec2-user@`${PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/init-db.sql"
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "Database initialization file uploaded successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: Failed to upload database initialization file" -ForegroundColor Yellow
        }
        
        # Update Docker registry in environment file on EC2
        Write-Host "Updating Docker registry configuration on EC2..." -ForegroundColor Yellow
        ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && sed -i 's/your-dockerhub-username/$DOCKER_USERNAME/g' .env"
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "Docker registry configuration updated successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: Failed to update Docker registry configuration" -ForegroundColor Yellow
        }
        
        # Restart services on EC2 instance
        Write-Host "Restarting services on EC2 instance..." -ForegroundColor Yellow
        ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@`${PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && docker-compose -f docker-compose.prod.yml down && docker-compose -f docker-compose.prod.yml up -d"
        if (`$LASTEXITCODE -eq 0) {
            Write-Host "Services restarted successfully" -ForegroundColor Green
        } else {
            Write-Host "Warning: Failed to restart services, you may need to do this manually" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Warning: Failed to upload environment file, you may need to do this manually" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: Environment file not found, skipping IP update" -ForegroundColor Yellow
}

Write-Host "Deployment complete!" -ForegroundColor Green
Write-Host "Your application is available at:" -ForegroundColor Cyan
Write-Host "   Frontend: http://`$PUBLIC_IP:3000" -ForegroundColor White
Write-Host "   Backend: http://`$PUBLIC_IP:3001" -ForegroundColor White
Write-Host "   SuperTokens: http://`$PUBLIC_IP:3567" -ForegroundColor White
Write-Host ""
Write-Host "SSH access: ssh -i ../supertokens-key.pem ec2-user@`${PUBLIC_IP}" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Wait 2-3 minutes for the instance to fully initialize" -ForegroundColor White
Write-Host "2. SSH into the instance to check service status" -ForegroundColor White
Write-Host "3. Run 'docker ps' to verify all containers are running" -ForegroundColor White
Write-Host "4. The same IP address will be used for future deployments (Elastic IP)" -ForegroundColor White
"@

$quickDeployContent | Out-File -FilePath "$DEPLOY_DIR\quick-deploy.ps1" -Encoding UTF8

Write-Host "Created quick deployment script" -ForegroundColor Green

# Create a destroy script
$destroyContent = @"
# Destroy infrastructure script

Write-Host "Destroying infrastructure..." -ForegroundColor Red
terraform destroy -auto-approve
Write-Host "Infrastructure destroyed" -ForegroundColor Green
"@

$destroyContent | Out-File -FilePath "$DEPLOY_DIR\destroy.ps1" -Encoding UTF8

Write-Host "Created destroy script" -ForegroundColor Green

# Copy database access management scripts
Write-Host "Copying database access management scripts" -ForegroundColor Green

Copy-Item "add-db-access.sh" "$DEPLOY_DIR\"
Copy-Item "remove-db-access.sh" "$DEPLOY_DIR\"

Write-Host "Copied database access scripts" -ForegroundColor Green

Write-Host ""
Write-Host "Deployment package created in: $DEPLOY_DIR" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Cyan
Write-Host "   - .env (production environment variables)" -ForegroundColor White
Write-Host "   - main.tf (Terraform infrastructure configuration)" -ForegroundColor White
Write-Host "   - DEPLOYMENT_INSTRUCTIONS.md (detailed deployment guide)" -ForegroundColor White
Write-Host "   - quick-deploy.ps1 (one-command deployment)" -ForegroundColor White
Write-Host "   - destroy.ps1 (cleanup script)" -ForegroundColor White
Write-Host "   - add-db-access.sh (enable direct database access)" -ForegroundColor White
Write-Host "   - remove-db-access.sh (disable direct database access)" -ForegroundColor White
Write-Host ""
Write-Host "To deploy:" -ForegroundColor Cyan
Write-Host "   1. cd $DEPLOY_DIR" -ForegroundColor White
Write-Host "   2. .\quick-deploy.ps1" -ForegroundColor White
Write-Host "   (SSH key pair will be created automatically)" -ForegroundColor White
Write-Host "   (Elastic IP will be used for consistent IP address)" -ForegroundColor White
Write-Host ""
Write-Host "Read DEPLOYMENT_INSTRUCTIONS.md for detailed steps" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated passwords:" -ForegroundColor Yellow
Write-Host "   PostgreSQL Root: $SUPERTOKENS_PASSWORD" -ForegroundColor White
Write-Host "   SuperTokens User: $SUPERTOKENS_PASSWORD" -ForegroundColor White
Write-Host "   App User: $APP_PASSWORD" -ForegroundColor White

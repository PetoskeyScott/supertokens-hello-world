#!/bin/bash

# SuperTokens Hello World - Complete Server Deployment Script
# Usage: ./deploy.sh <EC2_PUBLIC_IP> <YOUR_LAPTOP_IP>

set -e  # Exit on any error

# Check arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <EC2_PUBLIC_IP> <YOUR_LAPTOP_IP>"
    echo "Example: $0 54.166.10.160 192.168.1.100"
    exit 1
fi

EC2_PUBLIC_IP=$1
YOUR_LAPTOP_IP=$2

echo "🚀 Starting deployment to EC2 instance: $EC2_PUBLIC_IP"
echo "📱 Your laptop IP: $YOUR_LAPTOP_IP"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if you're authenticated with AWS
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "You are not authenticated with AWS. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS authentication verified"

# Create deployment directory
DEPLOY_DIR="deployment-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEPLOY_DIR"

# Generate strong passwords
POSTGRES_ROOT_PASSWORD=$(openssl rand -base64 32)
SUPERTOKENS_PASSWORD=$(openssl rand -base64 32)
APP_PASSWORD=$(openssl rand -base64 32)

print_status "Generated secure database passwords"

# Create secure secrets directory
SECRETS_DIR="$DEPLOY_DIR/.secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Store passwords in secure files
echo "$POSTGRES_ROOT_PASSWORD" > "$SECRETS_DIR/postgres_root"
echo "$SUPERTOKENS_PASSWORD" > "$SECRETS_DIR/supertokens_user"
echo "$APP_PASSWORD" > "$SECRETS_DIR/app_user"
chmod 600 "$SECRETS_DIR"/*

print_status "Created secure secrets directory"

# Create production environment file with file references
cat > "$DEPLOY_DIR/.env.production" << EOF
# Production Environment Variables
# Passwords are stored in .secrets/ directory for security

# PostgreSQL root password (for the main PostgreSQL instance)
POSTGRES_ROOT_PASSWORD=\$(cat .secrets/postgres_root)

# Database user passwords
SUPERTOKENS_PASSWORD=\$(cat .secrets/supertokens_user)
APP_PASSWORD=\$(cat .secrets/app_user)

# Frontend configuration
FRONTEND_URL=http://$EC2_PUBLIC_IP:3000
API_DOMAIN=http://$EC2_PUBLIC_IP:3001
WEBSITE_DOMAIN=http://$EC2_PUBLIC_IP:3000
EOF

# Create a .gitignore file to prevent secrets from being committed
cat > "$DEPLOY_DIR/.gitignore" << EOF
# Ignore secrets and environment files
.secrets/
.env.production
*.pem
*.key
EOF

print_status "Created production environment file with secure password handling"

# Create Terraform configuration
cat > "$DEPLOY_DIR/main.tf" << EOF
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

# VPC and Security Groups
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "supertokens-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "supertokens-igw"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"  # Change this to your preferred AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "supertokens-subnet"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "supertokens-rt"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "main" {
  name        = "supertokens-sg"
  description = "Security group for SuperTokens application"
  vpc_id      = aws_vpc.main.id

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

# EC2 Instance
resource "aws_instance" "main" {
  ami                    = "ami-0c02fb55956c7d316"  # Amazon Linux 2023 (change for your region)
  instance_type          = "t3.micro"
  key_name               = "supertokens-key"  # You'll need to create this key pair
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id              = aws_subnet.main.id

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Install Node.js
              curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
              source ~/.bashrc
              nvm install 18
              nvm use 18
              
              # Clone and deploy application
              cd /home/ec2-user
              git clone https://github.com/your-username/supertokens-hello-world.git
              cd supertokens-hello-world
              
              # Copy environment file
              cp .env.production .env.production
              
              # Start services
              docker-compose -f docker-compose.prod.yml up -d
              EOF

  tags = {
    Name = "supertokens-server"
  }

  depends_on = [aws_internet_gateway.main]
}

# Output the public IP
output "public_ip" {
  value = aws_instance.main.public_ip
}

output "instance_id" {
  value = aws_instance.instance_id
}
EOF

print_status "Created Terraform configuration"

# Create deployment instructions
cat > "$DEPLOY_DIR/DEPLOYMENT_INSTRUCTIONS.md" << EOF
# Deployment Instructions

## Prerequisites
1. AWS CLI installed and configured
2. Terraform installed
3. SSH key pair created in AWS (named 'supertokens-key')

## Steps to Deploy

### 1. Create SSH Key Pair in AWS
\`\`\`bash
aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text > supertokens-key.pem
chmod 400 supertokens-key.pem
\`\`\`

### 2. Deploy Infrastructure
\`\`\`bash
cd $DEPLOY_DIR
terraform init
terraform plan
terraform apply
\`\`\`

### 3. Wait for Instance to be Ready
The instance will take a few minutes to:
- Install Docker and Docker Compose
- Clone your repository
- Start all services

### 4. Verify Deployment
\`\`\`bash
# Get the public IP
terraform output public_ip

# SSH into the instance
ssh -i ../supertokens-key.pem ec2-user@<PUBLIC_IP>

# Check services
docker ps
docker-compose -f docker-compose.prod.yml ps
\`\`\`

### 5. Access Your Application
- Frontend: http://<PUBLIC_IP>:3000
- Backend API: http://<PUBLIC_IP>:3001
- SuperTokens Core: http://<PUBLIC_IP>:3567

## Destroy Infrastructure
\`\`\`bash
terraform destroy
\`\`\`

## Environment Variables
The following environment variables are automatically generated:
- POSTGRES_PASSWORD: $SUPERTOKENS_PASSWORD
- POSTGRES_APP_PASSWORD: $APP_PASSWORD

## Security Notes
- SSH access is restricted to your laptop IP: $YOUR_LAPTOP_IP
- Database passwords are randomly generated
- All services run in Docker containers
- Services automatically restart on reboot
EOF

print_status "Created deployment instructions"

# Create a simple deployment script
cat > "$DEPLOY_DIR/quick-deploy.sh" << 'EOF'
#!/bin/bash
# Quick deployment script

echo "🚀 Quick deployment starting..."

# Initialize Terraform
terraform init

# Plan the deployment
echo "📋 Planning deployment..."
terraform plan

# Apply the configuration
echo "🔨 Applying configuration..."
terraform apply -auto-approve

# Get the public IP
PUBLIC_IP=$(terraform output -raw public_ip)
echo "✅ Deployment complete!"
echo "🌐 Your application is available at:"
echo "   Frontend: http://$PUBLIC_IP:3000"
echo "   Backend: http://$PUBLIC_IP:3001"
echo "   SuperTokens: http://$PUBLIC_IP:3567"
echo ""
echo "🔑 SSH access: ssh -i ../supertokens-key.pem ec2-user@$PUBLIC_IP"
EOF

chmod +x "$DEPLOY_DIR/quick-deploy.sh"

print_status "Created quick deployment script"

# Create a destroy script
cat > "$DEPLOY_DIR/destroy.sh" << 'EOF'
#!/bin/bash
# Destroy infrastructure script

echo "🗑️  Destroying infrastructure..."
terraform destroy -auto-approve
echo "✅ Infrastructure destroyed"
EOF

chmod +x "$DEPLOY_DIR/destroy.sh"

# Copy database access management scripts
print_status "Copying database access management scripts"

cp add-db-access.sh "$DEPLOY_DIR/"
cp remove-db-access.sh "$DEPLOY_DIR/"
chmod +x "$DEPLOY_DIR/add-db-access.sh"
chmod +x "$DEPLOY_DIR/remove-db-access.sh"

print_status "Created destroy script"

echo ""
echo "🎉 Deployment package created in: $DEPLOY_DIR"
echo ""
echo "📁 Files created:"
echo "   - .env.production (production environment variables)"
echo "   - main.tf (Terraform infrastructure configuration)"
echo "   - DEPLOYMENT_INSTRUCTIONS.md (detailed deployment guide)"
echo "   - quick-deploy.sh (one-command deployment)"
echo "   - destroy.sh (cleanup script)"
echo "   - add-db-access.sh (enable direct database access)"
echo "   - remove-db-access.sh (disable direct database access)"
echo ""
echo "🚀 To deploy:"
echo "   1. cd $DEPLOY_DIR"
echo "   2. Create SSH key pair in AWS: aws ec2 create-key-pair --key-name supertokens-key --query 'KeyMaterial' --output text > supertokens-key.pem"
echo "   3. chmod 400 supertokens-key.pem"
echo "   4. ./quick-deploy.sh"
echo ""
echo "📚 Read DEPLOYMENT_INSTRUCTIONS.md for detailed steps"
echo ""
echo "🔑 Generated passwords:"
echo "   PostgreSQL Root: $POSTGRES_ROOT_PASSWORD"
echo "   SuperTokens User: $SUPERTOKENS_PASSWORD"
echo "   App User: $APP_PASSWORD"

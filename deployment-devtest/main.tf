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
git clone https://github.com/PetoskeyScott/supertokens-hello-world.git
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
ExecStart=/usr/bin/docker-compose -f docker-compose.dev.yml up -d
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

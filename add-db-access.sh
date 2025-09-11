#!/bin/bash

# Add Direct PostgreSQL Access Script
# Run this script on your EC2 instance to enable direct database access from your laptop
# Usage: ./add-db-access.sh <YOUR_LAPTOP_IP>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on EC2
if ! curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    print_error "This script must be run on an EC2 instance"
    exit 1
fi

# Check arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <YOUR_LAPTOP_IP>"
    echo "Example: $0 192.168.1.100"
    echo ""
    echo "This script will add a security group rule to allow direct PostgreSQL access"
    echo "from your laptop IP address to the EC2 instance."
    exit 1
fi

LAPTOP_IP=$1

echo "🔓 Adding direct PostgreSQL access from your laptop IP: $LAPTOP_IP"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
fi

# Get instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

print_status "Instance ID: $INSTANCE_ID"
print_status "Region: $REGION"

# Get security group ID
SECURITY_GROUP_ID=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --region $REGION \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

print_status "Security Group ID: $SECURITY_GROUP_ID"

# Check if PostgreSQL rule already exists
EXISTING_RULE=$(aws ec2 describe-security-groups \
    --group-ids $SECURITY_GROUP_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`]" \
    --output text)

if [ ! -z "$EXISTING_RULE" ]; then
    print_warning "PostgreSQL access rule already exists"
    echo "Current rules for port 5432:"
    aws ec2 describe-security-groups \
        --group-ids $SECURITY_GROUP_ID \
        --region $REGION \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`].IpRanges[].CidrIp" \
        --output table
else
    # Add PostgreSQL access rule
    print_status "Adding PostgreSQL access rule..."
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 5432 \
        --cidr $LAPTOP_IP/32 \
        --region $REGION \
        --description "PostgreSQL access from laptop $LAPTOP_IP"
    
    print_status "✅ PostgreSQL access rule added successfully!"
fi

echo ""
echo "🔍 Verifying the new rule..."
aws ec2 describe-security-groups \
    --group-ids $SECURITY_GROUP_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`]" \
    --output table

echo ""
echo "🎯 You can now connect to PostgreSQL directly from your laptop:"
echo ""
echo "   Connection Details:"
echo "   - Host: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "   - Port: 5432"
echo "   - Username: postgres, supertokens_user, or app_user"
echo "   - Password: Check your deployment .env.production file"
echo ""
echo "   Example psql commands:"
echo "   psql -h $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) -p 5432 -U postgres -d supertokens"
echo "   psql -h $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4) -p 5432 -U app_user -d supertokens_hello_world"
echo ""
echo "⚠️  Security Note: This rule allows direct database access from your laptop IP only."
echo "   Remember to remove this access when not needed for development/testing."
echo ""
echo "🔄 To remove this access later, run:"
echo "   ./remove-db-access.sh"

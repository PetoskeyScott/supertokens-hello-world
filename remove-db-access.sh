#!/bin/bash

# Remove Direct PostgreSQL Access Script
# Run this script on your EC2 instance to remove direct database access
# Usage: ./remove-db-access.sh

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

echo "🔒 Removing direct PostgreSQL access from your laptop"
echo ""

# Check if running on EC2
if ! curl -s http://169.254.169.254/latest/meta-data/instance-id > /dev/null 2>&1; then
    print_error "This script must be run on an EC2 instance"
    exit 1
fi

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
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

# Check current PostgreSQL rules
echo "🔍 Current PostgreSQL access rules:"
aws ec2 describe-security-groups \
    --group-ids $SECURITY_GROUP_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`].IpRanges[].CidrIp" \
    --output table

echo ""
print_warning "This will remove ALL direct PostgreSQL access rules from external IPs."
echo "Only internal container communication will remain."
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Operation cancelled. PostgreSQL access remains unchanged."
    exit 0
fi

# Remove all PostgreSQL ingress rules
print_status "Removing PostgreSQL access rules..."

# Get all IP ranges for port 5432
IP_RANGES=$(aws ec2 describe-security-groups \
    --group-ids $SECURITY_GROUP_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`].IpRanges[].CidrIp" \
    --output text)

if [ ! -z "$IP_RANGES" ]; then
    # Remove each IP range
    for IP_RANGE in $IP_RANGES; do
        print_status "Removing access from $IP_RANGE..."
        aws ec2 revoke-security-group-ingress \
            --group-id $SECURITY_GROUP_ID \
            --protocol tcp \
            --port 5432 \
            --cidr $IP_RANGE \
            --region $REGION
    done
    
    print_status "✅ All PostgreSQL access rules removed successfully!"
else
    print_status "No external PostgreSQL access rules found to remove."
fi

echo ""
echo "🔍 Verifying removal..."
aws ec2 describe-security-groups \
    --group-ids $SECURITY_GROUP_ID \
    --region $REGION \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`5432\` && ToPort==\`5432\` && IpProtocol==\`tcp\`]" \
    --output table

echo ""
print_status "✅ Direct PostgreSQL access has been removed."
echo "   Your database is now only accessible from within the EC2 instance."
echo "   Application containers can still communicate with PostgreSQL internally."
echo ""
echo "🔄 To re-enable direct access later, run:"
echo "   ./add-db-access.sh <YOUR_LAPTOP_IP>"

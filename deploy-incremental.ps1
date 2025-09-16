#!/usr/bin/env pwsh
# Incremental deployment script for code updates without password regeneration
# This script updates application code while preserving database passwords

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP,
    
    [string]$KEY_PATH = "./supertokens-key.pem",
    [switch]$ForcePasswordReset = $false
)

Write-Host "🚀 Incremental Deployment Script" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Check if key file exists
if (-not (Test-Path $KEY_PATH)) {
    Write-Host "❌ Error: Key file not found at $KEY_PATH" -ForegroundColor Red
    exit 1
}

# Get or create passwords
Write-Host "🔐 Managing passwords..." -ForegroundColor Yellow
if ($ForcePasswordReset) {
    Write-Host "🔄 Force resetting passwords..." -ForegroundColor Yellow
    $passwords = & "./manage-passwords.ps1" -Action "reset"
} else {
    $passwords = & "./manage-passwords.ps1" -Action "get"
    if (-not $passwords) {
        Write-Host "💡 No existing passwords found. Creating new ones..." -ForegroundColor Yellow
        $passwords = & "./manage-passwords.ps1" -Action "create"
    }
}

if (-not $passwords) {
    Write-Host "❌ Failed to get passwords" -ForegroundColor Red
    exit 1
}

# Create deployment directory
$DEPLOY_DIR = "deployment-incremental"
if (Test-Path $DEPLOY_DIR) {
    Remove-Item -Path $DEPLOY_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $DEPLOY_DIR -Force | Out-Null

Write-Host "📁 Created deployment directory: $DEPLOY_DIR" -ForegroundColor Green

# Create environment file with existing passwords
$envContent = @"
# Development/Testing Environment Variables
POSTGRES_ROOT_PASSWORD=$($passwords.POSTGRES_ROOT_PASSWORD)
SUPERTOKENS_PASSWORD=$($passwords.SUPERTOKENS_PASSWORD)
APP_PASSWORD=$($passwords.APP_PASSWORD)

# Frontend configuration
FRONTEND_URL=http://${EC2_PUBLIC_IP}:3000
API_DOMAIN=http://${EC2_PUBLIC_IP}:3001
WEBSITE_DOMAIN=http://${EC2_PUBLIC_IP}:3000
SUPERTOKENS_CONNECTION_URI=http://${EC2_PUBLIC_IP}:3567
"@

$envContent | Out-File -FilePath "$DEPLOY_DIR\.env.production" -Encoding UTF8
Write-Host "📝 Created environment file with existing passwords" -ForegroundColor Green

# Create the deployment script for EC2
$deployScript = @"
#!/bin/bash
set -e

echo "🔄 Starting incremental deployment..."

# Navigate to project directory
cd /home/ubuntu/supertokens-hello-world

echo "📥 Pulling latest code from GitHub..."
git pull origin main

echo "📤 Updating environment file..."
cp /home/ubuntu/.env.production .env

echo "🔧 Replacing IP placeholders..."
sed -i 's/PLACEHOLDER_IP/$EC2_PUBLIC_IP/g' .env

echo "🛑 Stopping application containers (keeping database running)..."
docker-compose -f docker-compose.dev.yml stop backend frontend supertokens-core

echo "🏗️  Rebuilding application containers..."
docker-compose -f docker-compose.dev.yml build --no-cache backend frontend supertokens-core

echo "🚀 Starting application containers..."
docker-compose -f docker-compose.dev.yml up -d backend frontend supertokens-core

echo "⏳ Waiting for services to start..."
sleep 15

echo "📊 Checking service status..."
docker-compose -f docker-compose.dev.yml ps

echo "✅ Incremental deployment completed!"
echo "Database passwords preserved - no data loss!"
"@

$deployScript | Out-File -FilePath "$DEPLOY_DIR/deploy-incremental-remote.sh" -Encoding UTF8

try {
    Write-Host "📤 Uploading deployment files to EC2..." -ForegroundColor Yellow
    scp -i $KEY_PATH -o StrictHostKeyChecking=no "$DEPLOY_DIR\.env.production" "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/.env.production"
    scp -i $KEY_PATH -o StrictHostKeyChecking=no "$DEPLOY_DIR/deploy-incremental-remote.sh" "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/"

    Write-Host "🚀 Executing incremental deployment on EC2..." -ForegroundColor Yellow
    ssh -i $KEY_PATH -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "chmod +x /home/ubuntu/deploy-incremental-remote.sh && /home/ubuntu/deploy-incremental-remote.sh"

    Write-Host ""
    Write-Host "✅ Incremental deployment completed successfully!" -ForegroundColor Green
    Write-Host "🔄 Application code updated while preserving database passwords" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your application is accessible at:" -ForegroundColor Cyan
    Write-Host "   Frontend: http://${EC2_PUBLIC_IP}:3000" -ForegroundColor White
    Write-Host "   Backend:  http://${EC2_PUBLIC_IP}:3001" -ForegroundColor White
    Write-Host "   SuperTokens Core: http://${EC2_PUBLIC_IP}:3567" -ForegroundColor White

} catch {
    Write-Host "❌ Error during deployment: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up deployment directory
    if (Test-Path $DEPLOY_DIR) {
        Remove-Item -Path $DEPLOY_DIR -Recurse -Force
        Write-Host "🧹 Cleaned up deployment files" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "💡 Monitor logs with:" -ForegroundColor Yellow
Write-Host "   ssh -i $KEY_PATH ubuntu@${EC2_PUBLIC_IP} 'cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml logs -f'" -ForegroundColor Gray

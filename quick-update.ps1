#!/usr/bin/env pwsh
# Quick update script for code-only changes
# This is the fastest way to deploy frontend/backend changes

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP,
    
    [string]$KEY_PATH = "./supertokens-key.pem"
)

Write-Host "⚡ Quick Code Update Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Check if key file exists
if (-not (Test-Path $KEY_PATH)) {
    Write-Host "❌ Error: Key file not found at $KEY_PATH" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Updating application code on EC2..." -ForegroundColor Yellow

# Create the quick update script for EC2
$updateScript = @"
#!/bin/bash
set -e

echo "⚡ Quick code update starting..."

# Navigate to project directory
cd /home/ubuntu/supertokens-hello-world

echo "📥 Pulling latest code from GitHub..."
git pull origin main

echo "🛑 Stopping application containers (keeping database running)..."
docker-compose -f docker-compose.dev.yml stop backend frontend supertokens-core

echo "🏗️  Rebuilding and starting application containers..."
docker-compose -f docker-compose.dev.yml up -d --build backend frontend supertokens-core

echo "⏳ Waiting for services to start..."
sleep 10

echo "📊 Checking service status..."
docker-compose -f docker-compose.dev.yml ps

echo "✅ Quick update completed!"
"@

$updateScript | Out-File -FilePath "quick-update-remote.sh" -Encoding UTF8

try {
    Write-Host "📤 Uploading update script to EC2..." -ForegroundColor Yellow
    scp -i $KEY_PATH -o StrictHostKeyChecking=no "quick-update-remote.sh" "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/"

    Write-Host "🚀 Executing quick update on EC2..." -ForegroundColor Yellow
    ssh -i $KEY_PATH -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "chmod +x /home/ubuntu/quick-update-remote.sh && /home/ubuntu/quick-update-remote.sh"

    Write-Host ""
    Write-Host "✅ Quick update completed successfully!" -ForegroundColor Green
    Write-Host "🔄 Application code updated - database untouched" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your application is accessible at:" -ForegroundColor Cyan
    Write-Host "   Frontend: http://${EC2_PUBLIC_IP}:3000" -ForegroundColor White
    Write-Host "   Backend:  http://${EC2_PUBLIC_IP}:3001" -ForegroundColor White

} catch {
    Write-Host "❌ Error during update: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temporary script
    if (Test-Path "quick-update-remote.sh") {
        Remove-Item "quick-update-remote.sh" -Force
        Write-Host "🧹 Cleaned up temporary files" -ForegroundColor Gray
    }
}

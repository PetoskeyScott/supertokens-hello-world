#!/usr/bin/env pwsh
# PowerShell script to clean up PostgreSQL volume and restart services
# This ensures the database is recreated with new passwords

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP,
    
    [string]$KEY_PATH = "./supertokens-key.pem"
)

Write-Host "🧹 PostgreSQL Volume Cleanup Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Check if key file exists
if (-not (Test-Path $KEY_PATH)) {
    Write-Host "❌ Error: Key file not found at $KEY_PATH" -ForegroundColor Red
    Write-Host "Please ensure the key file exists or specify the correct path with -KEY_PATH" -ForegroundColor Yellow
    exit 1
}

Write-Host "🔍 Connecting to EC2 instance: $EC2_PUBLIC_IP" -ForegroundColor Yellow

# Create the cleanup script that will run on the EC2 instance
$cleanupScript = @"
#!/bin/bash
set -e

echo "🛑 Stopping all Docker containers..."
cd /home/ubuntu/supertokens-hello-world
docker-compose -f docker-compose.dev.yml down

echo "🗑️  Removing PostgreSQL volume..."
docker volume rm supertokens-hello-world_postgres_data 2>/dev/null || echo "Volume may not exist or already removed"

echo "🧹 Cleaning up any orphaned containers and networks..."
docker system prune -f

echo "🔄 Starting services with fresh database..."
docker-compose -f docker-compose.dev.yml up -d --force-recreate

echo "⏳ Waiting for services to start..."
sleep 10

echo "📊 Checking service status..."
docker-compose -f docker-compose.dev.yml ps

echo "✅ PostgreSQL volume cleanup completed!"
echo "The database has been recreated with the new passwords from the .env file"
"@

# Write the cleanup script to a temporary file
$tempScript = "cleanup-postgres-remote.sh"
$cleanupScript | Out-File -FilePath $tempScript -Encoding UTF8

try {
    Write-Host "📤 Uploading cleanup script to EC2 instance..." -ForegroundColor Yellow
    scp -i $KEY_PATH -o StrictHostKeyChecking=no $tempScript "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/"

    Write-Host "🚀 Executing cleanup script on EC2 instance..." -ForegroundColor Yellow
    ssh -i $KEY_PATH -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "chmod +x /home/ubuntu/$tempScript && /home/ubuntu/$tempScript"

    Write-Host ""
    Write-Host "✅ PostgreSQL volume cleanup completed successfully!" -ForegroundColor Green
    Write-Host "The database has been recreated with the new passwords from your .env file" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 Your application should now be accessible at:" -ForegroundColor Cyan
    Write-Host "   Frontend: http://${EC2_PUBLIC_IP}:3000" -ForegroundColor White
    Write-Host "   Backend:  http://${EC2_PUBLIC_IP}:3001" -ForegroundColor White
    Write-Host "   SuperTokens Core: http://${EC2_PUBLIC_IP}:3567" -ForegroundColor White

} catch {
    Write-Host "❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Clean up temporary script
    if (Test-Path $tempScript) {
        Remove-Item $tempScript -Force
        Write-Host "🧹 Cleaned up temporary files" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "💡 Tip: You can monitor the logs with:" -ForegroundColor Yellow
Write-Host "   ssh -i $KEY_PATH ubuntu@${EC2_PUBLIC_IP} 'cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml logs -f'" -ForegroundColor Gray

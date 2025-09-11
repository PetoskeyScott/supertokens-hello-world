# Quick Development/Testing Deployment Script
# This script deploys the application to EC2 using GitHub clone

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP
)

Write-Host "Starting development/testing deployment to $EC2_PUBLIC_IP" -ForegroundColor Green

# Wait for instance to be ready
Write-Host "Waiting for EC2 instance to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Test SSH connection
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "ec2-user@${EC2_PUBLIC_IP}" "echo 'SSH connection successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed. Please check if the instance is ready and the key is correct."
    exit 1
}

Write-Host "SSH connection successful" -ForegroundColor Green

# Upload environment file
Write-Host "Uploading environment configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no ".env.production" "ec2-user@${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/.env.production"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Environment file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload environment file" -ForegroundColor Yellow
}

# Upload Docker Compose file
Write-Host "Uploading Docker Compose configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../docker-compose.dev.yml" "ec2-user@${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/docker-compose.prod.yml"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Docker Compose file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload Docker Compose file" -ForegroundColor Yellow
}

# Upload init-db.sql file
Write-Host "Uploading database initialization file..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "../init-db.sql" "ec2-user@${EC2_PUBLIC_IP}:/home/ec2-user/supertokens-hello-world/init-db.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database initialization file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload database initialization file" -ForegroundColor Yellow
}

# Update environment file with actual IP
Write-Host "Updating environment file with actual IP..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@${EC2_PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && sed -i 's/PLACEHOLDER_IP/${EC2_PUBLIC_IP}/g' .env.production"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Environment file updated successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to update environment file" -ForegroundColor Yellow
}

# Restart services on EC2 instance
Write-Host "Restarting services on EC2 instance..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ec2-user@${EC2_PUBLIC_IP}" "cd /home/ec2-user/supertokens-hello-world && docker-compose -f docker-compose.prod.yml down && docker-compose -f docker-compose.prod.yml up -d"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Services restarted successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to restart services" -ForegroundColor Yellow
}

Write-Host "Development/testing deployment completed!" -ForegroundColor Green
Write-Host "Frontend: http://$EC2_PUBLIC_IP:3000" -ForegroundColor Cyan
Write-Host "Backend API: http://$EC2_PUBLIC_IP:3001" -ForegroundColor Cyan
Write-Host "SuperTokens Core: http://$EC2_PUBLIC_IP:3567" -ForegroundColor Cyan

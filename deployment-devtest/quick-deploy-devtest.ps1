# Quick Development/Testing Deployment Script
# This script deploys the application to EC2 using GitHub clone

param(
    [Parameter(Mandatory=$true)]
    [string]$EC2_PUBLIC_IP,
    [Parameter(Mandatory=$true)]
    [string]$GITHUB_REPO_URL
)

Write-Host "Starting development/testing deployment to $EC2_PUBLIC_IP" -ForegroundColor Green

# Check if this is a new instance or existing one
$IS_NEW_INSTANCE = $EC2_PUBLIC_IP -eq "0.0.0.0"

if ($IS_NEW_INSTANCE) {
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
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "ubuntu@${EC2_PUBLIC_IP}" "echo 'SSH connection successful'"
if ($LASTEXITCODE -ne 0) {
    Write-Error "SSH connection failed. Please check if the instance is ready and the key is correct."
    exit 1
}

Write-Host "SSH connection successful" -ForegroundColor Green

# For existing instances, ensure repository is cloned and up to date
if (-not $IS_NEW_INSTANCE) {
    Write-Host "Setting up repository on existing instance..." -ForegroundColor Yellow
    
    # Check if repository exists and clone/update it
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "if [ ! -d '/home/ubuntu/supertokens-hello-world' ]; then cd /home/ubuntu && git clone https://github.com/PetoskeyScott/supertokens-hello-world.git; else cd /home/ubuntu/supertokens-hello-world && git pull; fi"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Repository setup/updated successfully" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to setup/update repository" -ForegroundColor Yellow
    }
    
    # Ensure Docker Compose is installed
    ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "which docker-compose > /dev/null || (sudo curl -L 'https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-Linux-x86_64' -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose)"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker Compose verified/installed" -ForegroundColor Green
    } else {
        Write-Host "Warning: Failed to install Docker Compose" -ForegroundColor Yellow
    }
}

# Upload environment file
Write-Host "Uploading environment configuration..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no ".env.production" "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/supertokens-hello-world/.env"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Environment file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload environment file" -ForegroundColor Yellow
}

# Docker Compose file comes from git pull, no need to upload
Write-Host "Docker Compose file will be used from git repository" -ForegroundColor Green

# Create init-db.sql with actual passwords
Write-Host "Creating database initialization file with actual passwords..." -ForegroundColor Yellow
 = Get-Content "../init-db.sql" -Raw
 =  -replace "PLACEHOLDER_SUPERTOKENS_PASSWORD", KOSiAIbops31aN60QC8jXMJfGeLEcwh7
 =  -replace "PLACEHOLDER_APP_PASSWORD", 7cxPUZgWtaM9hm2FOv4nCuSKeo5RjbyV
 | Out-File -FilePath "deployment-devtest\init-db.sql" -Encoding UTF8

# Upload init-db.sql file
Write-Host "Uploading database initialization file..." -ForegroundColor Yellow
scp -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "deployment-devtest\init-db.sql" "ubuntu@${EC2_PUBLIC_IP}:/home/ubuntu/supertokens-hello-world/init-db.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Database initialization file uploaded successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to upload database initialization file" -ForegroundColor Yellow
}

# Update environment file with actual IP
Write-Host "Updating environment file with actual IP..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && sed -i 's/PLACEHOLDER_IP/${EC2_PUBLIC_IP}/g' .env"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Environment file updated successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to update environment file" -ForegroundColor Yellow
}

# Stop existing services before restarting
Write-Host "Stopping existing services..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml down 2>/dev/null || true"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Existing services stopped" -ForegroundColor Green
} else {
    Write-Host "No existing services to stop" -ForegroundColor Yellow
}

# Restart services on EC2 instance
Write-Host "Starting services on EC2 instance..." -ForegroundColor Yellow
ssh -i "../supertokens-key.pem" -o StrictHostKeyChecking=no "ubuntu@${EC2_PUBLIC_IP}" "cd /home/ubuntu/supertokens-hello-world && docker-compose -f docker-compose.dev.yml down && docker-compose -f docker-compose.dev.yml up -d"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Services restarted successfully" -ForegroundColor Green
} else {
    Write-Host "Warning: Failed to restart services" -ForegroundColor Yellow
}

Write-Host "Development/testing deployment completed!" -ForegroundColor Green
Write-Host "Frontend: http://$EC2_PUBLIC_IP:3000" -ForegroundColor Cyan
Write-Host "Backend API: http://$EC2_PUBLIC_IP:3001" -ForegroundColor Cyan
Write-Host "SuperTokens Core: http://$EC2_PUBLIC_IP:3567" -ForegroundColor Cyan

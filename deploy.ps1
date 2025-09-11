# SuperTokens Hello World - Main Deployment Script
# This script helps you choose between development and production deployments

Write-Host "SuperTokens Hello World - Deployment Options" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Choose your deployment type:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Development/Testing (deploy-devtest.ps1)" -ForegroundColor Green
Write-Host "   - Fast deployment using GitHub clone" -ForegroundColor White
Write-Host "   - Builds Docker images on EC2" -ForegroundColor White
Write-Host "   - Perfect for testing changes quickly" -ForegroundColor White
Write-Host "   - No Docker Hub account required" -ForegroundColor White
Write-Host ""
Write-Host "2. Production (deploy-prod.ps1)" -ForegroundColor Red
Write-Host "   - Slow but production-ready deployment" -ForegroundColor White
Write-Host "   - Builds and pushes Docker images to Docker Hub" -ForegroundColor White
Write-Host "   - Uses pre-built images on EC2" -ForegroundColor White
Write-Host "   - Requires Docker Hub account" -ForegroundColor White
Write-Host ""
Write-Host "Usage:" -ForegroundColor Yellow
Write-Host "  Development: .\deploy-devtest.ps1 <EC2_PUBLIC_IP>" -ForegroundColor White
Write-Host "  Production:  .\deploy-prod.ps1 <YOUR_LAPTOP_IP>" -ForegroundColor White
Write-Host ""
Write-Host "Note: For development, you can use any EC2 public IP." -ForegroundColor Cyan
Write-Host "      For production, use your laptop's public IP for security group rules." -ForegroundColor Cyan

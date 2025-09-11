# Development/Testing Deployment

This deployment is optimized for fast iteration during development.

## What it does:
- Creates EC2 instance with GitHub clone
- Builds Docker images on EC2 (faster for development)
- No Docker registry required
- Quick deployment for testing changes

## Usage:
1. Run: .\deploy-devtest.ps1 <EC2_PUBLIC_IP>
2. Wait for Terraform to complete
3. Run: .\quick-deploy-devtest.ps1 <EC2_PUBLIC_IP>

## Files included:
- .env.production - Environment variables
- main.tf - Terraform configuration
- quick-deploy-devtest.ps1 - Quick deployment script
- docker-compose.prod.yml - Docker Compose configuration
- init-db.sql - Database initialization

## Note:
This is for development/testing only. Use deploy-prod.ps1 for production deployments.

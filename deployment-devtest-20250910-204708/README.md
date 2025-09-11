# Development/Testing Deployment

This deployment is optimized for fast iteration during development.

## Two Modes:

### New Instance Mode (0.0.0.0):
- Creates new EC2 instance with Terraform
- Clones repository via user_data script
- Full setup from scratch

### Existing Instance Mode (real IP):
- Uses existing EC2 instance
- Updates repository with git pull
- Stops existing services and redeploys
- Perfect for code changes

## What it does:
- Smart detection: 0.0.0.0 = new instance, real IP = existing instance
- Builds Docker images on EC2 (faster for development)
- No Docker registry required
- Quick deployment for testing changes

## Usage:
1. **New instance**: .\deploy-devtest.ps1 0.0.0.0
2. **Existing instance**: .\deploy-devtest.ps1 1.2.3.4
3. Wait for deployment to complete

## Files included:
- .env.production - Environment variables
- main.tf - Terraform configuration (new instance only)
- quick-deploy-devtest.ps1 - Quick deployment script
- docker-compose.prod.yml - Docker Compose configuration
- init-db.sql - Database initialization

## Note:
This is for development/testing only. Use deploy-prod.ps1 for production deployments.

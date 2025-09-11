# SuperTokens Hello World - Production Deployment

This document explains how to deploy the SuperTokens Hello World application to production using AWS EC2 with automated infrastructure management.

## 🚀 Quick Start

### 1. Generate Deployment Package
```bash
./deploy.sh <EC2_PUBLIC_IP> <YOUR_LAPTOP_IP>
```

Example:
```bash
./deploy.sh 54.166.10.160 192.168.1.100
```

### 2. Deploy to AWS
```bash
cd deployment-YYYYMMDD-HHMMSS
./quick-deploy.sh
```

### 3. Access Your Application
- Frontend: http://<EC2_IP>:3000
- Backend API: http://<EC2_IP>:3001
- SuperTokens Core: http://<EC2_IP>:3567

## 📋 Prerequisites

1. **AWS CLI** installed and configured
2. **Terraform** installed (version >= 1.0)
3. **SSH key pair** created in AWS (named 'supertokens-key')

## 🏗️ Architecture

The deployment creates:

- **VPC** with public subnet
- **EC2 Instance** (t3.micro) running Amazon Linux 2023
- **Security Groups** with proper port access
- **Docker containers** for all services
- **Auto-restart** on instance reboot

### Services Running:
1. **PostgreSQL** (port 5432) - SuperTokens core database
2. **PostgreSQL** (port 5433) - Application database
3. **SuperTokens Core** (port 3567) - Authentication service
4. **Backend API** (port 3001) - Node.js application
5. **Frontend** (port 3000) - React application

## 🔧 Configuration

### Environment Variables
The deployment automatically generates:
- Secure database passwords
- Proper service URLs
- Network configuration

### Security Features
- SSH access restricted to your laptop IP
- Database passwords randomly generated
- Services run in Docker containers
- Automatic service restart on failure

## 📁 Files Created

- `docker-compose.prod.yml` - Production service orchestration
- `backend/Dockerfile` - Backend container configuration
- `supertokens.service` - Systemd service for auto-start
- `deploy.sh` - Main deployment script generator
- `env.production.template` - Environment variable template
- `add-db-access.sh` - Enable direct database access from laptop
- `remove-db-access.sh` - Disable direct database access

## 🚀 Deployment Process

1. **Infrastructure Creation**
   - VPC, subnet, security groups
   - EC2 instance with proper configuration

2. **Instance Setup**
   - Install Docker and Docker Compose
   - Install Node.js
   - Clone application repository

3. **Service Deployment**
   - Start all Docker containers
   - Configure auto-restart
   - Verify service health

## 🔓 Database Access Management

### **Default Security (Recommended)**
By default, your deployment is **secure by design**:
- ✅ **No direct external access** to PostgreSQL database
- ✅ **Only internal container communication** allowed
- ✅ **SSH access** from your laptop only
- ✅ **Application ports** accessible for normal operation

### **Enabling Direct Database Access (Development/Testing)**
When you need direct database access from your laptop:

```bash
# SSH into your EC2 instance
ssh -i supertokens-key.pem ec2-user@<EC2_IP>

# Enable direct database access
./add-db-access.sh <YOUR_LAPTOP_IP>

# Now you can connect directly from laptop
psql -h <EC2_IP> -p 5432 -U postgres -d supertokens
psql -h <EC2_IP> -p 5432 -U app_user -d supertokens_hello_world
```

### **Removing Direct Database Access (Production)**
When you're done with development/testing:

```bash
# On EC2 instance
./remove-db-access.sh

# Database is now secure again
```

### **Connection Details**
- **Host:** Your EC2 public IP address
- **Port:** 5432
- **Usernames:** `postgres`, `supertokens_user`, `app_user`
- **Passwords:** Generated during deployment (check `.env.production`)

### **Security Considerations**
- 🔒 **IP Restricted** - Only your laptop IP can access
- ⚠️ **Temporary Use** - Enable only when needed
- 🚫 **Not for Production** - Remove access in production
- 🔄 **Easy Management** - Simple scripts to add/remove access

## 🔄 Disaster Recovery

### Complete Rebuild
```bash
# Destroy existing infrastructure
./destroy.sh

# Rebuild from scratch
./quick-deploy.sh
```

### Update Application
```bash
# SSH into instance
ssh -i supertokens-key.pem ec2-user@<EC2_IP>

# Pull latest code and restart
cd supertokens-hello-world
git pull
docker-compose -f docker-compose.prod.yml restart
```

## 📊 Monitoring

### Check Service Status
```bash
# View running containers
docker ps

# Check service logs
docker-compose -f docker-compose.prod.yml logs

# Monitor system resources
htop
```

### Health Checks
- Backend: `http://<EC2_IP>:3001/test`
- SuperTokens: `http://<EC2_IP>:3567/hello`

## 🛠️ Troubleshooting

### Common Issues

1. **Services not starting**
   ```bash
   # Check Docker status
   sudo systemctl status docker
   
   # View container logs
   docker-compose -f docker-compose.prod.yml logs
   ```

2. **Port access issues**
   - Verify security group rules
   - Check if services are running
   - Confirm port bindings

3. **Database connection errors**
   - Verify PostgreSQL containers are running
   - Check environment variables
   - Review connection strings
   - Use `./add-db-access.sh` if you need direct database access

4. **Need direct database access**
   ```bash
   # SSH into EC2 instance
   ssh -i supertokens-key.pem ec2-user@<EC2_IP>
   
   # Enable direct access
   ./add-db-access.sh <YOUR_LAPTOP_IP>
   
   # Test connection
   psql -h <EC2_IP> -p 5432 -U postgres -d supertokens
   ```

### Logs and Debugging
```bash
# View all service logs
docker-compose -f docker-compose.prod.yml logs -f

# Check specific service
docker-compose -f docker-compose.prod.yml logs backend

# System logs
sudo journalctl -u supertokens.service
```

## 🔒 Security Considerations

- **SSH Access**: Restricted to your laptop IP only
- **Database Passwords**: Automatically generated and secure
- **Network Isolation**: Services run in Docker network
- **Port Exposure**: Only necessary ports are open
- **Auto-updates**: System packages updated on deployment

## 💰 Cost Optimization

- **Instance Type**: t3.micro (free tier eligible)
- **Storage**: EBS volumes for data persistence
- **Network**: Minimal data transfer costs
- **Monitoring**: Use CloudWatch for cost tracking

## 📚 Additional Resources

- [SuperTokens Documentation](https://supertokens.com/docs)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section above
2. Review service logs and status
3. Verify infrastructure configuration
4. Check AWS console for instance status

---

**Note**: This deployment system is designed for development and testing. For production use, consider adding:
- Load balancers
- Auto-scaling groups
- Monitoring and alerting
- Backup and recovery procedures
- SSL/TLS certificates

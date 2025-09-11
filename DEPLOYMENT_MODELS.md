# SuperTokens Hello World - Deployment Models

This project now supports two distinct deployment models optimized for different use cases.

## 🚀 Development/Testing Deployment (`deploy-devtest.ps1`)

**Use this for:** Fast iteration during development and testing

### Characteristics:
- ⚡ **Fast** - 2-3 minutes total deployment time
- 🔄 **GitHub Clone** - Pulls latest code from repository
- 🏗️ **Build on EC2** - Docker images built on the server
- 🆓 **No Docker Hub** - No registry account required
- 🔧 **Easy Testing** - Perfect for trying changes quickly

### Workflow:
1. Make changes to your code
2. Push to GitHub
3. Run `.\deploy-devtest.ps1 <EC2_PUBLIC_IP>`
4. Test your changes
5. Repeat as needed

### Files Used:
- `docker-compose.dev.yml` - Builds from source
- GitHub repository clone
- Local environment configuration

---

## 🏭 Production Deployment (`deploy-prod.ps1`)

**Use this for:** Final production releases

### Characteristics:
- 🐌 **Slow** - 5-10 minutes total deployment time
- 🐳 **Docker Registry** - Pre-built images from Docker Hub
- 🔒 **Production Ready** - Consistent, tested builds
- 📦 **Registry Required** - Needs Docker Hub account
- 🚀 **Scalable** - Standard container deployment pattern

### Workflow:
1. Complete development and testing
2. Run `.\deploy-prod.ps1 <YOUR_LAPTOP_IP>`
3. Images built locally and pushed to Docker Hub
4. EC2 pulls pre-built images
5. Deploy to production

### Files Used:
- `docker-compose.prod.yml` - Uses registry images
- Docker Hub registry
- Production environment configuration

---

## 📁 File Structure

```
supertokens-hello-world/
├── deploy.ps1              # Main script (shows options)
├── deploy-devtest.ps1      # Development deployment
├── deploy-prod.ps1         # Production deployment
├── docker-compose.dev.yml  # Development Docker Compose
├── docker-compose.prod.yml # Production Docker Compose
├── frontend/
│   ├── Dockerfile          # Frontend Docker image
│   └── nginx.conf          # Nginx configuration
├── backend/
│   └── Dockerfile          # Backend Docker image
└── deployment-*/           # Generated deployment packages
```

---

## 🎯 When to Use Which?

### Use Development (`deploy-devtest.ps1`) when:
- ✅ Testing new features
- ✅ Debugging issues
- ✅ Rapid iteration
- ✅ Learning/experimenting
- ✅ Quick deployments

### Use Production (`deploy-prod.ps1`) when:
- ✅ Code is tested and ready
- ✅ Deploying to production
- ✅ Need consistent builds
- ✅ Team collaboration
- ✅ CI/CD pipeline

---

## 🔧 Setup Requirements

### For Development:
- AWS CLI configured
- EC2 instance (any public IP)
- GitHub repository access

### For Production:
- AWS CLI configured
- Docker Desktop installed
- Docker Hub account
- Your laptop's public IP

---

## 🚀 Quick Start

1. **Choose your deployment type:**
   ```powershell
   .\deploy.ps1
   ```

2. **For development:**
   ```powershell
   .\deploy-devtest.ps1 1.2.3.4
   ```

3. **For production:**
   ```powershell
   .\deploy-prod.ps1 1.2.3.4
   ```

---

## 💡 Pro Tips

- **Start with development** for testing changes
- **Switch to production** when ready to deploy
- **Use the same EC2 instance** for both (just restart services)
- **Keep Docker Hub images updated** for production
- **Test locally first** before any deployment

This dual-model approach gives you the best of both worlds: speed for development and reliability for production!

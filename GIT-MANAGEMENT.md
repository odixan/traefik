# Git Management for Traefik GitOps

This document explains what files are tracked in git and what files are ignored for security and operational reasons.

## 📁 **Tracked Files (Committed to Git)**

### Configuration Templates
- ✅ `example.env` - Environment template
- ✅ `docker-compose.yml` - Base configuration
- ✅ `docker-compose.prod.yml` - Production overrides
- ✅ `services/*.yml` - Service configurations
- ✅ `services/*.prod.yml` - Service production overrides
- ✅ `services/*.env.example` - Service environment templates

### Static Configuration
- ✅ `config/traefik.yaml` - Static Traefik configuration
- ✅ `config/dynamic/*.yaml` - Dynamic configuration files
- ✅ `README.md` - Documentation
- ✅ `services/README.md` - Service documentation

### Scripts and Tools
- ✅ `manage-services.sh` - Service management script
- ✅ `.gitignore` - Git ignore rules

### Directory Structure
- ✅ `logs/.gitkeep` - Preserves logs directory
- ✅ `config/certs/.gitkeep` - Preserves certs directory
- ✅ `config/dynamic/.gitkeep` - Preserves dynamic config directory

## 🚫 **Ignored Files (NOT Committed)**

### Security Sensitive
- ❌ `.env` - Environment variables with secrets
- ❌ `config/acme.json` - Let's Encrypt certificates
- ❌ `config/users.txt` - Basic auth credentials
- ❌ `config/certs/*.key` - Private keys
- ❌ `config/certs/*.crt` - Certificates (except examples)
- ❌ `secrets/` - Any secrets directory

### Runtime Data
- ❌ `logs/*.log` - Application logs
- ❌ `*-data/` - Docker volume data
- ❌ `volumes/` - Volume mounts

### Temporary Files
- ❌ `*.tmp` - Temporary files
- ❌ `.cache/` - Cache directories
- ❌ `backup/` - Backup files

### Development Files
- ❌ `.vscode/` - VS Code settings
- ❌ `.idea/` - IntelliJ settings
- ❌ `docker-compose.override.yml` - Local overrides

## 🔧 **Setup Instructions**

### Initial Repository Setup
```bash
# Clone repository
git clone <repository-url>
cd traefik

# Copy environment template
cp example.env .env
# Edit .env with your settings

# Create required files
touch config/acme.json
chmod 600 config/acme.json

# Generate certificates for development
cd config/certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout localhost.key -out localhost.crt \
  -subj "/C=US/ST=Local/L=Local/O=Local/OU=Local/CN=localhost"

# Start services
cd ../..
docker-compose up -d
```

### Before Committing Changes
```bash
# Check what will be committed
git status

# Ensure no sensitive files are staged
git diff --cached

# Add safe files only
git add docker-compose.yml config/traefik.yaml services/

# Commit changes
git commit -m "Add new service configuration"
```

## 🛡️ **Security Best Practices**

### Environment Variables
- Never commit `.env` files
- Always provide `.env.example` templates
- Use strong, unique passwords
- Rotate secrets regularly

### Certificates
- Let production certificates be generated automatically
- Don't commit private keys
- Use proper file permissions (600 for acme.json)

### Credentials
- Generate basic auth passwords using htpasswd
- Don't hardcode passwords in configuration files
- Use Docker secrets for sensitive data when possible

## 🔍 **Checking for Sensitive Data**

### Scan for Accidentally Committed Secrets
```bash
# Check for potential secrets in git history
git log --all --full-history -- .env
git log --all --full-history -- config/acme.json

# Search for patterns that might be secrets
git log -S "password" --all
git log -S "secret" --all
git log -S "key" --all
```

### Remove Sensitive Data (if accidentally committed)
```bash
# Remove file from git history (DANGEROUS - changes history)
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch .env' \
  --prune-empty --tag-name-filter cat -- --all

# Alternative: Use BFG Repo-Cleaner
java -jar bfg.jar --delete-files .env
git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

## 📋 **Regular Maintenance**

### Weekly Tasks
- Check for updates to base images
- Review logs for security issues
- Verify certificate expiration dates
- Check for new service configurations

### Monthly Tasks
- Rotate authentication credentials
- Review and update `.gitignore`
- Update documentation
- Test disaster recovery procedures

### Before Production Deployment
- Verify no development configurations are active
- Check all environment variables are set
- Test with production overrides
- Validate SSL certificates

## 🤝 **Team Guidelines**

### For Developers
- Always work on feature branches
- Test changes in development environment first
- Document any new environment variables
- Update service documentation when adding features

### For DevOps/SRE
- Review all pull requests for security issues
- Validate production configurations before merge
- Maintain environment-specific secrets securely
- Monitor for configuration drift

### Code Review Checklist
- [ ] No sensitive data in committed files
- [ ] Environment variables documented
- [ ] Production overrides tested
- [ ] Documentation updated
- [ ] Security configurations reviewed

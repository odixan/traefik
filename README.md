# Traefik GitOps Configuration

This repository contains a GitOps-ready Traefik configuration that supports both development and production environments.

## 🏗️ Architecture

### Development Environment
- **Certificates**: Self-signed certificates for `*.localhost` domains
- **Domains**: `traefik.localhost`, `portainer.localhost`
- **Access**: HTTP and HTTPS (with browser security warnings)

### Production Environment
- **Certificates**: Let's Encrypt automatic SSL certificates
- **Domains**: Your production domains (`traefik.yourdomain.com`, `portainer.yourdomain.com`)
- **Access**: HTTPS only with valid certificates

## 🚀 Quick Start

### Development Setup
```bash
# 1. Create proxy network
docker network create proxy

# 2. Copy and configure environment
cp example.env .env
# Edit .env with your settings

# 3. Start services
docker-compose up -d

# 4. Access services
curl -k https://traefik.localhost     # Traefik Dashboard
curl -k https://portainer.localhost   # Portainer UI
```

### Production Deployment
```bash
# 1. Create proxy network
docker network create proxy

# 2. Configure production environment
cp example.env .env
# Edit .env:
# - Set DOMAIN=yourdomain.com
# - Set EMAIL=your-email@yourdomain.com
# - Generate proper TRAEFIK_DASHBOARD_CREDENTIALS

# 3. Deploy with production override
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# 4. Access services (DNS should point to your server)
curl https://traefik.yourdomain.com     # Traefik Dashboard
curl https://portainer.yourdomain.com   # Portainer UI
```

## 📁 File Structure

```
├── docker-compose.yml          # Base configuration
├── docker-compose.prod.yml     # Production overrides
├── example.env                 # Environment template
├── config/
│   ├── traefik.yaml           # Static Traefik configuration
│   ├── acme.json              # Let's Encrypt certificates storage
│   ├── users.txt              # Basic auth users
│   ├── certs/                 # Self-signed certificates (dev)
│   │   ├── localhost.crt
│   │   └── localhost.key
│   └── dynamic/               # Dynamic configuration
│       ├── middlewares.yaml   # Security middlewares
│       └── tls.yaml          # TLS/certificate configuration
└── logs/                      # Traefik logs
```

## 🔒 Security Features

### Middlewares Available
- **Security Headers**: HSTS, CSP, security headers
- **Basic Authentication**: Username/password protection
- **Rate Limiting**: Request throttling
- **IP Allowlist**: IP-based access control
- **CORS**: Cross-origin resource sharing

### TLS Configuration
- **Modern**: TLS 1.3 only (recommended for production)
- **Default**: TLS 1.2+ (balanced compatibility)
- **Legacy**: TLS 1.0+ (for older clients)

## 🌍 Environment Configuration

### Environment Variables (.env)
```bash
# Required
TRAEFIK_DASHBOARD_CREDENTIALS=admin:$$2y$$10$$hashed_password

# Production only
DOMAIN=yourdomain.com
EMAIL=your-email@yourdomain.com
TZ=Europe/Madrid
```

### Generating Credentials
```bash
# Generate hashed password
echo $(htpasswd -nb admin your_password) | sed -e s/\\$/\\$\\$/g
```

## 🔧 Customization

### Adding New Services
Add labels to your services in docker-compose.yml:

```yaml
services:
  your-app:
    labels:
      - "traefik.enable=true"
      # Development
      - "traefik.http.routers.app.rule=Host(\`app.localhost\`)"
      - "traefik.http.routers.app.entrypoints=web"
      # Production (add to docker-compose.prod.yml)
      - "traefik.http.routers.app-prod.rule=Host(\`app.${DOMAIN}\`)"
      - "traefik.http.routers.app-prod.entrypoints=websecure"
      - "traefik.http.routers.app-prod.tls.certresolver=letsencrypt"
```

### Custom Domains in Development
Update `/etc/hosts`:
```
127.0.0.1 traefik.localhost
127.0.0.1 portainer.localhost
127.0.0.1 your-app.localhost
```

## 🐛 Troubleshooting

### Check Service Health
```bash
docker-compose ps
docker-compose logs traefik
```

### Verify Certificates
```bash
# Development (self-signed)
openssl s_client -connect traefik.localhost:443 -servername traefik.localhost

# Production (Let's Encrypt)
openssl s_client -connect traefik.yourdomain.com:443 -servername traefik.yourdomain.com
```

### Access Dashboard
- **Development**: http://traefik.localhost or https://traefik.localhost (ignore warnings)
- **Production**: https://traefik.yourdomain.com

## 📚 Resources

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Docker Compose Override](https://docs.docker.com/compose/extends/)

## 🤝 Contributing

1. Test changes in development environment first
2. Ensure production override works correctly
3. Update documentation for any new features
4. Verify both HTTP and HTTPS access work properly

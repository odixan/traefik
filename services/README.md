# Adding New Services to Traefik

This guide shows how to add new services to your Traefik GitOps setup using Pi-hole as an example.

## 📁 Service Structure

```
services/
├── pihole.yml              # Base service configuration
├── pihole.prod.yml         # Production overrides
├── pihole.env.example      # Environment template
└── README.md               # This file
```

## 🚀 Quick Start

### 1. Setup Pi-hole (Development)

```bash
# Copy environment template
cp services/pihole.env.example pihole.env
# Edit pihole.env with your settings

# Start Pi-hole with Traefik
docker-compose -f docker-compose.yml -f services/pihole.yml up -d

# Access Pi-hole
curl -k https://pihole.localhost
```

### 2. Setup Pi-hole (Production)

```bash
# Add Pi-hole variables to your main .env file
cat services/pihole.env.example >> .env
# Edit .env with production settings

# Deploy with production override
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f services/pihole.yml \
  -f services/pihole.prod.yml \
  up -d

# Access Pi-hole
curl https://pihole.yourdomain.com
```

## 🔧 Service Configuration Template

When adding a new service, follow this pattern:

```yaml
# services/your-service.yml
networks:
  proxy:
    external: true
  your-service:  # Optional: internal network
    driver: bridge

services:
  your-service:
    image: your-service:latest
    container_name: your-service
    restart: unless-stopped
    networks:
      - proxy
      - your-service  # If using internal network

    # Ports (only if needed outside Traefik)
    ports:
      - "custom-port:internal-port"

    environment:
      - SERVICE_VAR=${SERVICE_VAR}

    volumes:
      - service_data:/data

    labels:
      - "traefik.enable=true"

      # HTTP routes
      - "traefik.http.routers.service.rule=Host(\`service.localhost\`)"
      - "traefik.http.routers.service.entrypoints=web"
      - "traefik.http.routers.service.service=service"
      - "traefik.http.services.service.loadbalancer.server.port=80"

      # HTTPS routes (development)
      - "traefik.http.routers.service-secure-local.rule=Host(\`service.localhost\`)"
      - "traefik.http.routers.service-secure-local.entrypoints=websecure"
      - "traefik.http.routers.service-secure-local.tls=true"
      - "traefik.http.routers.service-secure-local.service=service"

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3

    deploy:
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M

    security_opt:
      - no-new-privileges:true

    depends_on:
      - traefik

volumes:
  service_data:
    driver: local
    name: service_data
```

## 🌍 Production Override Template

```yaml
# services/your-service.prod.yml
services:
  your-service:
    environment:
      - PRODUCTION_VAR=${PRODUCTION_VAR}

    labels:
      # Production HTTPS routes
      - "traefik.http.routers.service-secure-prod.rule=Host(\`service.${DOMAIN}\`)"
      - "traefik.http.routers.service-secure-prod.entrypoints=websecure"
      - "traefik.http.routers.service-secure-prod.tls=true"
      - "traefik.http.routers.service-secure-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.service-secure-prod.service=service"

      # Disable development routes
      - "traefik.http.routers.service.rule=Host(\`_disabled_\`)"
      - "traefik.http.routers.service-secure-local.rule=Host(\`_disabled_\`)"
```

## 🛡️ Security Best Practices

### 1. Network Isolation
```yaml
networks:
  proxy:
    external: true
  service-internal:
    driver: bridge
    internal: true  # No internet access
```

### 2. Resource Limits
```yaml
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
    reservations:
      memory: 256M
      cpus: '0.25'
```

### 3. Security Options
```yaml
security_opt:
  - no-new-privileges:true
  - seccomp:unconfined  # Only if needed
cap_drop:
  - ALL
cap_add:
  - SPECIFIC_CAPABILITY  # Only what's needed
```

### 4. Middleware Usage
```yaml
labels:
  # Add security headers
  - "traefik.http.routers.service.middlewares=security-headers@file"

  # Add authentication
  - "traefik.http.routers.service.middlewares=basic-auth@file"

  # Rate limiting
  - "traefik.http.routers.service.middlewares=rate-limit@file"

  # Combine middlewares
  - "traefik.http.routers.service.middlewares=security-headers@file,basic-auth@file"
```

## 🔍 Common Service Examples

### Web Application
```yaml
labels:
  - "traefik.http.services.webapp.loadbalancer.server.port=3000"
  - "traefik.http.routers.webapp.middlewares=security-headers@file"
```

### API Service
```yaml
labels:
  - "traefik.http.routers.api.rule=Host(\`api.localhost\`) && PathPrefix(\`/api\`)"
  - "traefik.http.routers.api.middlewares=cors@file,rate-limit@file"
```

### Database Admin (with auth)
```yaml
labels:
  - "traefik.http.routers.dbadmin.middlewares=basic-auth@file"
  - "traefik.http.routers.dbadmin.rule=Host(\`db.localhost\`)"
```

## 📋 Deployment Commands

### Development
```bash
# Single service
docker-compose -f docker-compose.yml -f services/service.yml up -d

# Multiple services
docker-compose \
  -f docker-compose.yml \
  -f services/pihole.yml \
  -f services/nextcloud.yml \
  up -d
```

### Production
```bash
# With production overrides
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  -f services/service.yml \
  -f services/service.prod.yml \
  up -d
```

### Scaling
```bash
# Scale specific service
docker-compose -f docker-compose.yml -f services/api.yml up -d --scale api=3
```

## 🐛 Troubleshooting

### Check Service Status
```bash
docker-compose -f docker-compose.yml -f services/service.yml ps
docker-compose -f docker-compose.yml -f services/service.yml logs service
```

### Verify Traefik Routes
```bash
# Check Traefik dashboard
curl -k https://traefik.localhost

# Test service endpoint
curl -k https://service.localhost
```

### Debug Networking
```bash
# Check networks
docker network ls
docker network inspect traefik_proxy

# Check container connectivity
docker exec traefik ping service
```

## 📚 Additional Examples

See the `services/` directory for more examples:
- `pihole.yml` - DNS server with ad blocking
- `nextcloud.yml` - File sharing and collaboration
- `grafana.yml` - Monitoring and dashboards
- `gitlab.yml` - Git repository and CI/CD

## 🤝 Contributing New Services

1. Create base service file: `services/service.yml`
2. Create production override: `services/service.prod.yml`
3. Create environment template: `services/service.env.example`
4. Test in development environment
5. Verify production deployment
6. Document any special requirements

# Simple Traefik Integration Guide

## How to Add Traefik to Your App (2 Minutes) 🚀

**Just add ONE file to your app and get enterprise-grade infrastructure!**

---

## Quick Start

### 1. Copy Template to Your App
Choose the template that matches your app:

| App Type | Template File | Use Case |
|----------|---------------|----------|
| **Web App** | `web-application.yml` | React, Vue, Angular, static sites |
| **API Service** | `api-service.yml` | REST APIs, microservices |
| **Full-Stack** | `fullstack-application.yml` | Frontend + Backend together |

```bash
# Copy the template you need
curl -O https://raw.githubusercontent.com/yourorg/traefik/master/templates/fullstack-application.yml

# Rename it
mv fullstack-application.yml docker-compose.traefik.yml
```

### 2. Set Your App Variables
Add these to your `.env` file:

```bash
SERVICE_NAME=myapp
SERVICE_PORT=3000
PRODUCTION_DOMAIN=myapp.yourdomain.com
```

### 3. Update Your docker-compose.yml
Remove the `ports:` section (Traefik handles routing):

```yaml
# BEFORE
services:
  web:
    build: .
    ports:
      - "3000:3000"  # ❌ Remove this

# AFTER
services:
  web:
    build: .
    # ✅ No ports needed - Traefik handles it
```

### 4. Start Your App
```bash
docker-compose -f docker-compose.yml -f docker-compose.traefik.yml up -d
```

### 5. Access Your App
```bash
# Clean URLs instead of localhost:3000
http://myapp.localhost      # Your app
https://myapp.localhost     # With HTTPS
https://myapp.localhost/api # Your API
```

---

## What You Get Automatically

✅ **HTTPS certificates** (self-signed for dev, Let's Encrypt for production)
✅ **Load balancing** across multiple instances
✅ **Security headers** (HSTS, CSP, etc.)
✅ **Health checks** and failover
✅ **Rate limiting** in production
✅ **Clean URLs** (no more port numbers!)

---

## Real Example: Node.js + React App

### Your Current Setup
```yaml
# docker-compose.yml
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:80"

  backend:
    build: ./backend
    ports:
      - "3001:3000"
```

### Add This File: docker-compose.traefik.yml
```yaml
networks:
  proxy:
    external: true

services:
  frontend:
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}-frontend.rule=Host(`${SERVICE_NAME}.localhost`)"
      - "traefik.http.routers.${SERVICE_NAME}-frontend-secure.rule=Host(`${SERVICE_NAME}.localhost`)"
      - "traefik.http.routers.${SERVICE_NAME}-frontend-secure.entrypoints=websecure"
      - "traefik.http.routers.${SERVICE_NAME}-frontend-secure.tls=true"
      - "traefik.http.services.${SERVICE_NAME}-frontend.loadbalancer.server.port=80"

  backend:
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}-backend.rule=Host(`${SERVICE_NAME}.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.${SERVICE_NAME}-backend-secure.rule=Host(`${SERVICE_NAME}.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.${SERVICE_NAME}-backend-secure.entrypoints=websecure"
      - "traefik.http.routers.${SERVICE_NAME}-backend-secure.tls=true"
      - "traefik.http.services.${SERVICE_NAME}-backend.loadbalancer.server.port=3000"
```

### Environment Variables (.env)
```bash
SERVICE_NAME=myapp
FRONTEND_PORT=80
BACKEND_PORT=3000
```

---

## Before vs After

| Before (Ports) | After (Domains) |
|----------------|-----------------|
| `localhost:3000` | `myapp.localhost` |
| `localhost:3001/api` | `myapp.localhost/api` |
| HTTP only | HTTPS included |
| Manual SSL setup | Automatic certificates |
| Port conflicts | Clean domains |

---

## Production Deployment

Add `docker-compose.prod.yml` for production:

```yaml
services:
  frontend:
    labels:
      - "traefik.http.routers.${SERVICE_NAME}-frontend-prod.rule=Host(`${PRODUCTION_DOMAIN}`)"
      - "traefik.http.routers.${SERVICE_NAME}-frontend-prod.entrypoints=websecure"
      - "traefik.http.routers.${SERVICE_NAME}-frontend-prod.tls.certresolver=letsencrypt"

  backend:
    labels:
      - "traefik.http.routers.${SERVICE_NAME}-backend-prod.rule=Host(`${PRODUCTION_DOMAIN}`) && PathPrefix(`/api`)"
      - "traefik.http.routers.${SERVICE_NAME}-backend-prod.entrypoints=websecure"
      - "traefik.http.routers.${SERVICE_NAME}-backend-prod.tls.certresolver=letsencrypt"
```

Deploy:
```bash
# Production with automatic Let's Encrypt certificates
docker-compose -f docker-compose.yml -f docker-compose.traefik.yml -f docker-compose.prod.yml up -d
```

---

## Common Use Cases

### Single Page App (React/Vue)
```yaml
services:
  app:
    networks: [default, proxy]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`${SERVICE_NAME}.localhost`)"
      - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=80"
```

### API Only
```yaml
services:
  api:
    networks: [default, proxy]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`api.localhost`) && PathPrefix(`/v1/${SERVICE_NAME}`)"
      - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=3000"
```

### Database Admin (with auth)
```yaml
services:
  adminer:
    networks: [default, proxy]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${SERVICE_NAME}-db.rule=Host(`${SERVICE_NAME}-db.localhost`)"
      - "traefik.http.routers.${SERVICE_NAME}-db.middlewares=basic-auth@file"
      - "traefik.http.services.${SERVICE_NAME}-db.loadbalancer.server.port=8080"
```

---

## Validation

```bash
# Check if everything is configured correctly
./scripts/validate-traefik-config.sh

# ✅ Docker Compose syntax is valid
# ✅ External 'proxy' network exists
# ✅ Traefik labels validation passed
# ✅ All validations passed! 🎉
```

---

## Getting Help

- 🎯 **Quick Start**: This file
- 📖 **Full Documentation**: [APPLICATION-INTEGRATION.md](./APPLICATION-INTEGRATION.md)
- 🛠️ **All Templates**: [templates/](./templates/) directory
- 🔧 **Validation Tools**: [scripts/](./scripts/) directory

---

## Summary

1. **Copy template** → `docker-compose.traefik.yml`
2. **Set environment variables** → `SERVICE_NAME`, `SERVICE_PORT`
3. **Remove ports from main compose** → Traefik handles routing
4. **Start with both files** → Get enterprise infrastructure

**Result**: Your app gets HTTPS, load balancing, security, health checks, and clean URLs with zero application code changes!

**From port chaos to domain elegance in 2 minutes.** ✨

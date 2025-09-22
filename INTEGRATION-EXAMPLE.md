# Application Integration Example

## Real Application Repository Structure

Here's exactly what you add to your application repository:

```
my-awesome-app/
├── src/
├── package.json
├── Dockerfile
├── docker-compose.yml          # Your existing app configuration
├── docker-compose.traefik.yml  # 👈 ADD THIS FILE (copy from template)
└── .env                        # 👈 ADD THESE VARIABLES
```

## Example: Node.js + React Application

### Step 1: Your Existing docker-compose.yml
```yaml
# docker-compose.yml (your existing file)
services:
  frontend:
    build: ./frontend
    ports:
      - "3000:80"
    environment:
      - REACT_APP_API_URL=http://localhost:3001/api

  backend:
    build: ./backend
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=development
      - PORT=3000
```

### Step 2: Add docker-compose.traefik.yml (copy from template)
```yaml
# docker-compose.traefik.yml (ADD THIS FILE)
networks:
  proxy:
    external: true

services:
  frontend:
    networks:
      - default
      - proxy
    environment:
      - REACT_APP_API_URL=https://myapp.localhost/api  # Updated for Traefik
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-frontend.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.myapp-frontend.entrypoints=web"
      - "traefik.http.routers.myapp-frontend-secure.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.myapp-frontend-secure.entrypoints=websecure"
      - "traefik.http.routers.myapp-frontend-secure.tls=true"
      - "traefik.http.services.myapp-frontend.loadbalancer.server.port=80"
      - "traefik.http.routers.myapp-frontend-secure.middlewares=security-headers@file"

  backend:
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp-backend.rule=Host(`myapp.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.myapp-backend.entrypoints=web"
      - "traefik.http.routers.myapp-backend-secure.rule=Host(`myapp.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.myapp-backend-secure.entrypoints=websecure"
      - "traefik.http.routers.myapp-backend-secure.tls=true"
      - "traefik.http.services.myapp-backend.loadbalancer.server.port=3000"
      - "traefik.http.routers.myapp-backend-secure.middlewares=security-headers@file,cors@file"
```

### Step 3: Update your .env file
```bash
# Add these to your .env file
SERVICE_NAME=myapp
FRONTEND_PORT=80
BACKEND_PORT=3000
PRODUCTION_DOMAIN=myapp.yourdomain.com
```

### Step 4: Start with Traefik Integration
```bash
# Remove port mappings from docker-compose.yml (Traefik handles routing)
# Start your app with Traefik integration
docker-compose -f docker-compose.yml -f docker-compose.traefik.yml up -d
```

### Step 5: Access Your App
```bash
# Before (with ports)
curl http://localhost:3000     # Frontend
curl http://localhost:3001/api # Backend

# After (with Traefik - much cleaner!)
curl http://myapp.localhost         # Frontend
curl https://myapp.localhost        # Frontend (HTTPS)
curl https://myapp.localhost/api    # Backend API (HTTPS)
```

## What Changed vs What Stays the Same

### ✅ Stays the Same (Zero Application Changes)
- Your application code
- Your Dockerfile
- Your build process
- Your environment variables (mostly)
- Your database connections
- Your internal service communication

### 🔄 What Changes (Infrastructure Only)
- Remove port mappings from docker-compose.yml
- Add `proxy` network to services
- Add Traefik labels for routing
- Update frontend API URL to use the domain
- Start with additional compose file

## Before/After Comparison

### Before: Port-Based Access
```bash
# Development team has to remember different ports
Frontend:  http://localhost:3000
Backend:   http://localhost:3001/api
Database:  http://localhost:8080 (adminer)
Docs:      http://localhost:8081
```

### After: Domain-Based Access
```bash
# Clean, memorable URLs for development
Frontend:  https://myapp.localhost
Backend:   https://myapp.localhost/api
Database:  https://myapp-db.localhost
Docs:      https://myapp-docs.localhost
```

## Production Deployment

Add one more file for production:

```yaml
# docker-compose.prod.yml
services:
  frontend:
    environment:
      - REACT_APP_API_URL=https://myapp.yourdomain.com/api
    labels:
      - "traefik.http.routers.myapp-frontend-prod.rule=Host(`myapp.yourdomain.com`)"
      - "traefik.http.routers.myapp-frontend-prod.entrypoints=websecure"
      - "traefik.http.routers.myapp-frontend-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.myapp-frontend-prod.service=myapp-frontend"

  backend:
    labels:
      - "traefik.http.routers.myapp-backend-prod.rule=Host(`myapp.yourdomain.com`) && PathPrefix(`/api`)"
      - "traefik.http.routers.myapp-backend-prod.entrypoints=websecure"
      - "traefik.http.routers.myapp-backend-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.myapp-backend-prod.service=myapp-backend"
```

Deploy to production:
```bash
docker-compose -f docker-compose.yml -f docker-compose.traefik.yml -f docker-compose.prod.yml up -d
```

## Summary

1. **Copy template** → `docker-compose.traefik.yml`
2. **Customize variables** → Update SERVICE_NAME, ports
3. **Remove port mappings** → Let Traefik handle routing
4. **Start with both files** → Your app now has enterprise-grade infrastructure

**Result**: Your app gets HTTPS, load balancing, security headers, health checks, and production-ready configuration with minimal effort!

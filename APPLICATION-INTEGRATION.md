# Application Integration with Traefik Infrastructure

This document explains how applications can consume the Traefik infrastructure standards we've established. It provides templates, patterns, and examples for different types of applications.

## Table of Contents
1. [Integration Approaches](#integration-approaches)
2. [Standard Label Templates](#standard-label-templates)
3. [Application Examples](#application-examples)
4. [Environment Configuration](#environment-configuration)
5. [Best Practices](#best-practices)

## Integration Approaches

### 1. Application-Centric Approach (Recommended for Multi-Team)

In this approach, each application repository includes its own `docker-compose.override.yml` or service definition that references the shared Traefik infrastructure.

**Pros:**
- Team autonomy - each team manages their own service configuration
- Faster development cycles - no dependency on infrastructure team for service changes
- Clear service ownership and responsibility
- Easy to test and deploy individual services

**Cons:**
- Potential configuration drift between services
- Need for shared standards and validation
- More complex service discovery

### 2. Infrastructure-Centric Approach (GitOps)

All service definitions are managed in this infrastructure repository under `services/`.

**Pros:**
- Centralized configuration management
- Consistent standards enforcement
- Easier to manage networking and dependencies
- Single source of truth

**Cons:**
- Infrastructure team becomes bottleneck
- Slower development cycles for application teams
- Tighter coupling between infrastructure and applications

## Standard Label Templates

### Basic Web Application Template

```yaml
labels:
  - "traefik.enable=true"

  # HTTP routing (development)
  - "traefik.http.routers.${SERVICE_NAME}.rule=Host(`${SERVICE_NAME}.localhost`)"
  - "traefik.http.routers.${SERVICE_NAME}.entrypoints=web"
  - "traefik.http.routers.${SERVICE_NAME}.service=${SERVICE_NAME}"

  # HTTPS routing (development with self-signed certs)
  - "traefik.http.routers.${SERVICE_NAME}-secure-local.rule=Host(`${SERVICE_NAME}.localhost`)"
  - "traefik.http.routers.${SERVICE_NAME}-secure-local.entrypoints=websecure"
  - "traefik.http.routers.${SERVICE_NAME}-secure-local.tls=true"
  - "traefik.http.routers.${SERVICE_NAME}-secure-local.service=${SERVICE_NAME}"

  # Service definition
  - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=${SERVICE_PORT}"

  # Apply standard middlewares
  - "traefik.http.routers.${SERVICE_NAME}-secure-local.middlewares=security-headers@file,compress@file"
```

### Production Override Template

```yaml
labels:
  # Production domain routing
  - "traefik.http.routers.${SERVICE_NAME}-prod.rule=Host(`${PRODUCTION_DOMAIN}`)"
  - "traefik.http.routers.${SERVICE_NAME}-prod.entrypoints=websecure"
  - "traefik.http.routers.${SERVICE_NAME}-prod.tls.certresolver=letsencrypt"
  - "traefik.http.routers.${SERVICE_NAME}-prod.service=${SERVICE_NAME}"
  - "traefik.http.routers.${SERVICE_NAME}-prod.middlewares=security-headers@file,compress@file,rate-limit@file"
```

### API Service Template

```yaml
labels:
  - "traefik.enable=true"

  # API routing with path prefix
  - "traefik.http.routers.${SERVICE_NAME}-api.rule=Host(`api.localhost`) && PathPrefix(`/${API_VERSION}/${SERVICE_NAME}`)"
  - "traefik.http.routers.${SERVICE_NAME}-api.entrypoints=web"
  - "traefik.http.routers.${SERVICE_NAME}-api.service=${SERVICE_NAME}"

  # HTTPS API routing
  - "traefik.http.routers.${SERVICE_NAME}-api-secure.rule=Host(`api.localhost`) && PathPrefix(`/${API_VERSION}/${SERVICE_NAME}`)"
  - "traefik.http.routers.${SERVICE_NAME}-api-secure.entrypoints=websecure"
  - "traefik.http.routers.${SERVICE_NAME}-api-secure.tls=true"
  - "traefik.http.routers.${SERVICE_NAME}-api-secure.service=${SERVICE_NAME}"

  # Service configuration
  - "traefik.http.services.${SERVICE_NAME}.loadbalancer.server.port=${SERVICE_PORT}"

  # API-specific middlewares
  - "traefik.http.routers.${SERVICE_NAME}-api-secure.middlewares=security-headers@file,cors@file,rate-limit@file"
```

## Application Examples

### Example 1: Node.js Web Application

Create this in your application repository as `docker-compose.traefik.yml`:

```yaml
# docker-compose.traefik.yml
# Include this in your application repository
# Usage: docker-compose -f docker-compose.yml -f docker-compose.traefik.yml up -d

networks:
  proxy:
    external: true

services:
  web:
    # Your existing service configuration...
    networks:
      - default
      - proxy
    environment:
      - NODE_ENV=${NODE_ENV:-development}
      - PORT=3000
    labels:
      - "traefik.enable=true"

      # Development routing
      - "traefik.http.routers.myapp.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.myapp.entrypoints=web"
      - "traefik.http.routers.myapp.service=myapp"

      # HTTPS development routing
      - "traefik.http.routers.myapp-secure.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.myapp-secure.entrypoints=websecure"
      - "traefik.http.routers.myapp-secure.tls=true"
      - "traefik.http.routers.myapp-secure.service=myapp"

      # Service definition
      - "traefik.http.services.myapp.loadbalancer.server.port=3000"

      # Middlewares
      - "traefik.http.routers.myapp-secure.middlewares=security-headers@file"

      # Health check endpoint for Traefik
      - "traefik.http.services.myapp.loadbalancer.healthcheck.path=/health"
      - "traefik.http.services.myapp.loadbalancer.healthcheck.interval=30s"
```

**Usage in application repository:**
```bash
# Start your app with Traefik integration
docker-compose -f docker-compose.yml -f docker-compose.traefik.yml up -d

# Access your app
curl http://myapp.localhost
curl https://myapp.localhost  # Self-signed cert
```

### Example 2: Python Flask API

```yaml
# docker-compose.traefik.yml for Flask API
networks:
  proxy:
    external: true

services:
  api:
    networks:
      - default
      - proxy
    environment:
      - FLASK_ENV=${FLASK_ENV:-development}
      - FLASK_PORT=5000
    labels:
      - "traefik.enable=true"

      # API routing
      - "traefik.http.routers.myapi.rule=Host(`api.localhost`) && PathPrefix(`/v1/myapi`)"
      - "traefik.http.routers.myapi.entrypoints=web"
      - "traefik.http.routers.myapi.service=myapi"

      # HTTPS API routing
      - "traefik.http.routers.myapi-secure.rule=Host(`api.localhost`) && PathPrefix(`/v1/myapi`)"
      - "traefik.http.routers.myapi-secure.entrypoints=websecure"
      - "traefik.http.routers.myapi-secure.tls=true"
      - "traefik.http.routers.myapi-secure.service=myapi"

      # Service configuration
      - "traefik.http.services.myapi.loadbalancer.server.port=5000"

      # API middlewares
      - "traefik.http.routers.myapi-secure.middlewares=security-headers@file,cors@file,rate-limit@file"

      # Strip path prefix if your API doesn't expect it
      - "traefik.http.middlewares.myapi-stripprefix.stripprefix.prefixes=/v1/myapi"
      - "traefik.http.routers.myapi.middlewares=myapi-stripprefix"
      - "traefik.http.routers.myapi-secure.middlewares=security-headers@file,cors@file,rate-limit@file,myapi-stripprefix"
```

### Example 3: Frontend + Backend Application

```yaml
# docker-compose.traefik.yml for full-stack app
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

      # Frontend routing
      - "traefik.http.routers.frontend.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.frontend.entrypoints=web"
      - "traefik.http.routers.frontend.service=frontend"

      # HTTPS frontend routing
      - "traefik.http.routers.frontend-secure.rule=Host(`myapp.localhost`)"
      - "traefik.http.routers.frontend-secure.entrypoints=websecure"
      - "traefik.http.routers.frontend-secure.tls=true"
      - "traefik.http.routers.frontend-secure.service=frontend"

      # Service definition
      - "traefik.http.services.frontend.loadbalancer.server.port=80"

      # Frontend middlewares
      - "traefik.http.routers.frontend-secure.middlewares=security-headers@file"

  backend:
    networks:
      - default
      - proxy
    labels:
      - "traefik.enable=true"

      # Backend API routing
      - "traefik.http.routers.backend.rule=Host(`myapp.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.backend.entrypoints=web"
      - "traefik.http.routers.backend.service=backend"

      # HTTPS backend routing
      - "traefik.http.routers.backend-secure.rule=Host(`myapp.localhost`) && PathPrefix(`/api`)"
      - "traefik.http.routers.backend-secure.entrypoints=websecure"
      - "traefik.http.routers.backend-secure.tls=true"
      - "traefik.http.routers.backend-secure.service=backend"

      # Service configuration
      - "traefik.http.services.backend.loadbalancer.server.port=3000"

      # Backend middlewares
      - "traefik.http.routers.backend-secure.middlewares=security-headers@file,cors@file,rate-limit@file"
```

## Environment Configuration

### Application .env Template

Create this template for application teams:

```bash
# .env template for applications using Traefik
# Copy to your application repository and customize

# Service configuration
SERVICE_NAME=myapp
SERVICE_PORT=3000
API_VERSION=v1

# Development domains
DEV_DOMAIN=${SERVICE_NAME}.localhost
API_DEV_DOMAIN=api.localhost

# Production domains (override in production)
PRODUCTION_DOMAIN=${SERVICE_NAME}.example.com
API_PRODUCTION_DOMAIN=api.example.com

# Environment
NODE_ENV=development
FLASK_ENV=development

# Health check configuration
HEALTH_CHECK_PATH=/health
HEALTH_CHECK_INTERVAL=30s

# Traefik network (should match infrastructure)
TRAEFIK_NETWORK=proxy
```

### Production Environment Overrides

```yaml
# docker-compose.prod.yml - production overrides for applications
services:
  web:
    labels:
      # Override development labels for production
      - "traefik.http.routers.${SERVICE_NAME}-prod.rule=Host(`${PRODUCTION_DOMAIN}`)"
      - "traefik.http.routers.${SERVICE_NAME}-prod.entrypoints=websecure"
      - "traefik.http.routers.${SERVICE_NAME}-prod.tls.certresolver=letsencrypt"
      - "traefik.http.routers.${SERVICE_NAME}-prod.service=${SERVICE_NAME}"
      - "traefik.http.routers.${SERVICE_NAME}-prod.middlewares=security-headers@file,compress@file,rate-limit@file"

      # Disable development routes in production
      - "traefik.http.routers.${SERVICE_NAME}.rule="
      - "traefik.http.routers.${SERVICE_NAME}-secure.rule="
```

## Best Practices

### 1. Standard Naming Conventions

- Service names: `kebab-case` (e.g., `my-app`, `user-service`)
- Router names: `${service-name}`, `${service-name}-secure`, `${service-name}-prod`
- Domain patterns: `${service-name}.localhost` (dev), `${service-name}.yourdomain.com` (prod)

### 2. Health Checks

Always implement health check endpoints in your applications:

```javascript
// Node.js Express example
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});
```

### 3. Environment Separation

Use different router names and rules for different environments:
- Development: `.localhost` domains
- Staging: `.staging.yourdomain.com` domains
- Production: `.yourdomain.com` domains

### 4. Security Standards

Always apply these middlewares in production:
- `security-headers@file` - Essential security headers
- `rate-limit@file` - Prevent abuse
- `compress@file` - Improve performance

### 5. Logging and Monitoring

Configure proper logging in your applications:

```yaml
services:
  myapp:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    labels:
      # Add service metadata for monitoring
      - "traefik.http.services.myapp.loadbalancer.healthcheck.path=/health"
      - "traefik.http.services.myapp.loadbalancer.healthcheck.interval=30s"
      - "org.opencontainers.image.title=My Application"
      - "org.opencontainers.image.version=1.0.0"
```

## Shared Configuration Strategy

For teams using the application-centric approach, consider these strategies:

### 1. Shared Configuration Repository

Create a separate repository with shared configurations:

```bash
# Shared repo structure
shared-configs/
├── traefik/
│   ├── templates/
│   │   ├── web-app.yml
│   │   ├── api-service.yml
│   │   └── database.yml
│   ├── middlewares/
│   │   └── custom-middlewares.yml
│   └── scripts/
│       ├── validate-config.sh
│       └── generate-labels.sh
```

### 2. Git Submodules

Include shared configurations as submodules:

```bash
# In your application repository
git submodule add https://github.com/yourorg/shared-configs.git shared-configs
```

### 3. Configuration Validation

Create validation scripts that teams can run:

```bash
#!/bin/bash
# validate-traefik-config.sh
# Validates that Traefik labels follow standards

docker-compose -f docker-compose.yml -f docker-compose.traefik.yml config --quiet
if [ $? -eq 0 ]; then
  echo "✅ Traefik configuration is valid"
else
  echo "❌ Traefik configuration has errors"
  exit 1
fi
```

This approach gives you the best of both worlds: team autonomy with shared standards and validation.

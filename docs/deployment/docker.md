# Chat API - Docker Guide

Complete guide for running Chat API with Docker in development and production environments.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start (Development)](#quick-start-development)
- [Development Setup](#development-setup)
- [Production Deployment](#production-deployment)
- [Docker Commands Reference](#docker-commands-reference)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Prerequisites

### Install Docker

**macOS:**
```bash
# Install Docker Desktop
brew install --cask docker

# Or download from: https://www.docker.com/products/docker-desktop
```

**Linux:**
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Verify installation
docker --version
docker-compose --version
```

**Windows:**
- Download Docker Desktop: https://www.docker.com/products/docker-desktop
- Enable WSL 2 backend

### Verify Installation

```bash
# Check Docker
docker --version
# Output: Docker version 24.x.x

# Check Docker Compose
docker-compose --version
# Output: Docker Compose version v2.x.x
```

---

## Quick Start (Development)

Get Chat API running in 3 commands:

```bash
# 1. Clone repository (if not already)
git clone <your-repo-url>
cd chat-api

# 2. Start all services
docker-compose up

# 3. Setup database (in another terminal)
docker-compose exec web rails db:create db:migrate
```

**Access:**
- **API:** http://localhost:3000/api/v1/ping
- **Swagger UI:** http://localhost:3000/api-docs
- **ActiveAdmin:** http://localhost:3000/admin
- **Flipper UI:** http://localhost:3000/flipper

---

## Development Setup

### Architecture

```
┌─────────────────────────────────────────┐
│           Docker Compose                │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │PostgreSQL│  │  Redis   │            │
│  │  :5432   │  │  :6379   │            │
│  └──────────┘  └──────────┘            │
│       │             │                   │
│       └─────┬───────┘                   │
│             │                           │
│       ┌─────▼─────┐  ┌──────────┐      │
│       │   Rails   │  │ Sidekiq  │      │
│       │   :3000   │  │(bg jobs) │      │
│       └───────────┘  └──────────┘      │
│                                         │
└─────────────────────────────────────────┘
         │
         │ Port 3000
         ▼
   Your Frontend
```

### Project Structure

```
chat-api/
├── Dockerfile              # Production build
├── Dockerfile.dev          # Development build
├── docker-compose.yml      # Dev environment orchestration
├── .dockerignore          # Files to exclude from build
└── docs/
    └── deployment/
        └── docker.md      # This file
```

### Step-by-Step Setup

#### Step 1: Environment Variables

Create `.env` file (if not exists):

```bash
# Copy from example
cp .env.example .env
```

**Minimal .env for Docker:**
```bash
# Database (Docker uses these)
POSTGRES_HOST=postgres
POSTGRES_USER=chat_api
POSTGRES_PASSWORD=password
POSTGRES_DB=chat_api_development

# Redis
REDIS_URL=redis://redis:6379/0

# JWT
JWT_SECRET_KEY=your_secret_key_from_rails_secret

# CORS
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
```

**Note:** Database credentials are handled by docker-compose.yml for development.

#### Step 2: Start Services

```bash
# Start all services (PostgreSQL, Redis, Rails, Sidekiq)
docker-compose up

# Or run in background
docker-compose up -d
```

**Expected output:**
```
Creating chat_api_postgres ... done
Creating chat_api_redis    ... done
Creating chat_api_web      ... done
Creating chat_api_sidekiq  ... done
```

#### Step 3: Setup Database

**In another terminal:**

```bash
# Create database
docker-compose exec web rails db:create

# Run migrations
docker-compose exec web rails db:migrate

# Seed data (optional)
docker-compose exec web rails db:seed
```

#### Step 4: Verify Everything Works

```bash
# Check services are running
docker-compose ps

# Should show:
# chat_api_postgres  Up  5432/tcp
# chat_api_redis     Up  6379/tcp
# chat_api_web       Up  0.0.0.0:3000->3000/tcp
# chat_api_sidekiq   Up

# Test API
curl http://localhost:3000/api/v1/ping

# Expected response:
# {"success":true,"data":{"message":"pong",...}}
```

---

### Common Development Tasks

#### Access Rails Console

```bash
docker-compose exec web rails console

# Or shorter:
docker-compose exec web rails c
```

#### Run Tests

```bash
# Run all tests
docker-compose exec web rspec

# Run specific test
docker-compose exec web rspec spec/models/user_spec.rb

# With coverage
docker-compose exec web rspec
docker-compose exec web open coverage/index.html
```

#### Run Migrations

```bash
# Create new migration
docker-compose exec web rails generate migration AddFieldToModel field:type

# Run pending migrations
docker-compose exec web rails db:migrate

# Rollback last migration
docker-compose exec web rails db:rollback

# Check migration status
docker-compose exec web rails db:migrate:status
```

#### View Logs

```bash
# All services
docker-compose logs

# Specific service
docker-compose logs web
docker-compose logs postgres
docker-compose logs redis
docker-compose logs sidekiq

# Follow logs (real-time)
docker-compose logs -f web

# Last 100 lines
docker-compose logs --tail=100 web
```

#### Install New Gems

```bash
# Add gem to Gemfile
vim Gemfile

# Install gem
docker-compose exec web bundle install

# Rebuild image (if needed)
docker-compose build web
```

#### Access Database

```bash
# PostgreSQL shell
docker-compose exec postgres psql -U chat_api -d chat_api_development

# Run SQL query
docker-compose exec postgres psql -U chat_api -d chat_api_development -c "SELECT * FROM users;"

# Or use Rails dbconsole
docker-compose exec web rails dbconsole
```

#### Access Redis CLI

```bash
# Redis CLI
docker-compose exec redis redis-cli

# Test Redis
> PING
PONG

> SET test "Hello Docker"
OK

> GET test
"Hello Docker"

> EXIT
```

#### Restart Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart web

# Stop and start (full restart)
docker-compose down && docker-compose up
```

#### Clean Up

```bash
# Stop all services
docker-compose stop

# Stop and remove containers
docker-compose down

# Remove containers, networks, and volumes
docker-compose down -v

# Remove everything including images
docker-compose down -v --rmi all
```

---

## Production Deployment

### Using Production Dockerfile

Your project includes a production-optimized Dockerfile.

**Features:**
- ✅ Multi-stage build (smaller image)
- ✅ Non-root user (secure)
- ✅ Jemalloc (memory optimization)
- ✅ Bootsnap precompilation
- ✅ Thruster for HTTP/2

### Build Production Image

```bash
# Build image
docker build -t chat-api:latest .

# Test locally
docker run -d \
  -p 3000:80 \
  -e RAILS_MASTER_KEY=<your-master-key> \
  -e DATABASE_URL=postgresql://user:pass@host:5432/dbname \
  -e REDIS_URL=redis://redis-host:6379/0 \
  -e CORS_ORIGINS=https://myapp.com \
  --name chat-api \
  chat-api:latest

# Check logs
docker logs -f chat-api
```

---

### Deployment Platforms

#### Option 1: Railway

**Deploy to Railway:**

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Set environment variables
railway variables set CORS_ORIGINS=https://myapp.com
railway variables set JWT_SECRET_KEY=your_secret

# Deploy
railway up

# Open app
railway open
```

**Railway will automatically:**
- Detect Dockerfile
- Build image
- Deploy to production
- Provide PostgreSQL and Redis add-ons

---

#### Option 2: Render

**Deploy to Render:**

1. **Create render.yaml:**

```yaml
# render.yaml
services:
  - type: web
    name: chat-api
    env: docker
    dockerfilePath: ./Dockerfile
    envVars:
      - key: DATABASE_URL
        fromDatabase:
          name: chat-api-db
          property: connectionString
      - key: REDIS_URL
        fromService:
          name: chat-api-redis
          property: connectionString
      - key: CORS_ORIGINS
        value: https://myapp.com
      - key: JWT_SECRET_KEY
        generateValue: true

databases:
  - name: chat-api-db
    databaseName: chat_api_production
    user: chat_api

  - name: chat-api-redis
    plan: starter
```

2. **Deploy:**
   - Push to GitHub
   - Connect repository to Render
   - Render auto-deploys on push

---

#### Option 3: Fly.io

**Deploy to Fly.io:**

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login
fly auth login

# Launch app (first time)
fly launch

# Deploy
fly deploy

# Set secrets
fly secrets set CORS_ORIGINS=https://myapp.com
fly secrets set JWT_SECRET_KEY=your_secret

# Open app
fly open
```

---

#### Option 4: Kamal (Self-Hosted)

**Deploy with Kamal:**

```bash
# Install Kamal
gem install kamal

# Initialize Kamal
kamal init

# Edit config/deploy.yml
# (Kamal configuration)

# Setup servers
kamal setup

# Deploy
kamal deploy

# View logs
kamal app logs
```

---

#### Option 5: Kubernetes

**Deploy to Kubernetes:**

Create `k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chat-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: chat-api
  template:
    metadata:
      labels:
        app: chat-api
    spec:
      containers:
      - name: chat-api
        image: your-registry/chat-api:latest
        ports:
        - containerPort: 80
        env:
        - name: RAILS_ENV
          value: "production"
        - name: CORS_ORIGINS
          valueFrom:
            configMapKeyRef:
              name: chat-api-config
              key: cors-origins
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: chat-api-secrets
              key: database-url
```

**Deploy:**
```bash
kubectl apply -f k8s/
```

---

## Docker Commands Reference

### Essential Commands

```bash
# Start services
docker-compose up              # Foreground
docker-compose up -d           # Background (detached)

# Stop services
docker-compose stop            # Stop containers (keep them)
docker-compose down            # Stop and remove containers

# Restart
docker-compose restart         # Restart all services
docker-compose restart web     # Restart specific service

# View status
docker-compose ps              # List containers
docker ps                      # List all containers
docker-compose top             # Show processes

# Logs
docker-compose logs            # All logs
docker-compose logs -f web     # Follow web logs
docker-compose logs --tail=50  # Last 50 lines

# Execute commands
docker-compose exec web <command>     # Run in web container
docker-compose run web <command>      # Run in new container

# Build
docker-compose build           # Rebuild all images
docker-compose build web       # Rebuild web image
docker-compose build --no-cache  # Build without cache

# Clean up
docker-compose down -v         # Remove volumes
docker system prune            # Clean unused Docker data
docker volume prune            # Remove unused volumes
```

### Database Commands

```bash
# Rails database tasks
docker-compose exec web rails db:create
docker-compose exec web rails db:migrate
docker-compose exec web rails db:seed
docker-compose exec web rails db:reset
docker-compose exec web rails db:rollback

# Access PostgreSQL
docker-compose exec postgres psql -U chat_api -d chat_api_development

# Backup database
docker-compose exec postgres pg_dump -U chat_api chat_api_development > backup.sql

# Restore database
docker-compose exec -T postgres psql -U chat_api -d chat_api_development < backup.sql
```

### Rails Commands

```bash
# Console
docker-compose exec web rails console

# Routes
docker-compose exec web rails routes

# Generate
docker-compose exec web rails generate model User email:string
docker-compose exec web rails generate controller Api::V1::Users

# Tests
docker-compose exec web rspec
docker-compose exec web rspec spec/models/

# Code quality
docker-compose exec web rubocop
docker-compose exec web brakeman
```

---

## Troubleshooting

### Issue 1: Port Already in Use

**Error:**
```
ERROR: for postgres  Cannot start service postgres:
Ports are not available: exposing port TCP 0.0.0.0:5432
```

**Solution:**
```bash
# Find process using port 5432
lsof -i :5432

# Kill the process
kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "5433:5432"  # Use different host port
```

---

### Issue 2: Database Connection Failed

**Error:**
```
PG::ConnectionBad: could not connect to server
```

**Solution:**
```bash
# Check if postgres is healthy
docker-compose ps

# Check postgres logs
docker-compose logs postgres

# Restart postgres
docker-compose restart postgres

# Wait for health check
docker-compose up -d postgres
sleep 10
docker-compose up web
```

---

### Issue 3: Bundle Install Fails

**Error:**
```
Gem::Ext::BuildError: ERROR: Failed to build gem native extension
```

**Solution:**
```bash
# Rebuild with no cache
docker-compose build --no-cache web

# Or install build dependencies in Dockerfile.dev
RUN apt-get install -y build-essential
```

---

### Issue 4: Volume Permission Issues

**Error:**
```
Permission denied @ dir_s_mkdir - /rails/tmp
```

**Solution:**
```bash
# Fix permissions on host
sudo chown -R $(whoami) .

# Or in docker-compose.yml, run as current user
user: "${UID}:${GID}"
```

---

### Issue 5: Changes Not Reflected

**Error:**
Code changes don't appear in running container.

**Solution:**
```bash
# Check volume mounts in docker-compose.yml
volumes:
  - .:/rails  # Make sure this exists

# Restart web service
docker-compose restart web

# Or rebuild
docker-compose up --build
```

---

### Issue 6: Out of Disk Space

**Error:**
```
no space left on device
```

**Solution:**
```bash
# Clean unused Docker data
docker system prune -a

# Remove unused volumes
docker volume prune

# Remove all stopped containers
docker container prune
```

---

## Best Practices

### Development Best Practices

#### 1. Use .dockerignore

```bash
# .dockerignore
.git
.gitignore
README.md
.env
tmp/
log/
coverage/
.DS_Store
```

#### 2. Volume Mounts for Hot Reload

```yaml
# docker-compose.yml
volumes:
  - .:/rails           # Mount code
  - bundle_cache:/usr/local/bundle  # Cache gems
```

#### 3. Health Checks

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U chat_api"]
  interval: 10s
  timeout: 5s
  retries: 5
```

#### 4. Use .env Files

```bash
# docker-compose.yml
env_file:
  - .env
```

---

### Production Best Practices

#### 1. Multi-Stage Builds

```dockerfile
# Use separate build and runtime stages
FROM ruby:3.4.8-slim AS build
# ... build steps

FROM ruby:3.4.8-slim AS runtime
# ... runtime only
```

#### 2. Non-Root User

```dockerfile
RUN useradd -m -u 1000 rails
USER 1000:1000
```

#### 3. Minimize Layers

```dockerfile
# Bad: Multiple RUN commands
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get clean

# Good: Single RUN command
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists
```

#### 4. Use Specific Image Tags

```dockerfile
# Bad: Latest tag
FROM ruby:latest

# Good: Specific version
FROM ruby:3.4.8-slim
```

#### 5. Secrets Management

```bash
# Use Docker secrets or environment variables
# Never hardcode secrets in Dockerfile

# Use build args for non-sensitive data
ARG RUBY_VERSION=3.4.8
```

---

## Environment Variables for Docker

### Development (.env)

```bash
# Database
POSTGRES_HOST=postgres
POSTGRES_USER=chat_api
POSTGRES_PASSWORD=password
POSTGRES_DB=chat_api_development

# Redis
REDIS_URL=redis://redis:6379/0

# Rails
RAILS_ENV=development
RAILS_MAX_THREADS=5

# CORS
CORS_ORIGINS=http://localhost:5173,http://localhost:3000

# JWT
JWT_SECRET_KEY=your_dev_secret
```

### Production

```bash
# Database
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Redis
REDIS_URL=redis://host:6379/0

# Rails
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# CORS
CORS_ORIGINS=https://myapp.com

# JWT
JWT_SECRET_KEY=your_production_secret

# Rails Master Key (for credentials)
RAILS_MASTER_KEY=<from config/master.key>
```

---

## Next Steps

After setting up Docker:

1. **Development:**
   - Start coding with `docker-compose up`
   - Run tests with `docker-compose exec web rspec`
   - Make changes - hot reload works automatically

2. **Production:**
   - Choose deployment platform (Railway, Render, Fly.io)
   - Set environment variables
   - Deploy with `docker build` or platform CLI

3. **CI/CD:**
   - Setup GitHub Actions
   - Build Docker images in CI
   - Deploy automatically on merge to main

---

## Resources

- **Docker Documentation:** https://docs.docker.com
- **Docker Compose Documentation:** https://docs.docker.com/compose
- **Rails Docker Guide:** https://guides.rubyonrails.org/getting_started_with_devcontainer.html
- **Kamal Documentation:** https://kamal-deploy.org
- **Best Practices:** https://docs.docker.com/develop/dev-best-practices

---

**Happy Dockerizing! 🐳**

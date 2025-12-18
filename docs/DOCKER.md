# Docker Fundamentals Guide

A comprehensive guide to Docker containerization for Kubernetes deployments.

---

## 📋 Table of Contents

1. [What is Docker?](#what-is-docker)
2. [Docker Architecture](#docker-architecture)
3. [Core Concepts](#core-concepts)
4. [Dockerfile Best Practices](#dockerfile-best-practices)
5. [Multi-Stage Builds](#multi-stage-builds)
6. [Image Optimization](#image-optimization)
7. [Docker Commands](#docker-commands)
8. [Docker Compose](#docker-compose)
9. [Container Networking](#container-networking)
10. [Working with ECR](#working-with-ecr)

---

## What is Docker?

Docker is a platform for developing, shipping, and running applications in **containers**. Containers package your application with all its dependencies, ensuring it runs consistently across environments.

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Traditional vs Containerized                      │
│                                                                      │
│   Traditional Deployment          Container Deployment               │
│   ┌─────────────────────┐        ┌─────────────────────┐            │
│   │  App 1   │   App 2  │        │ Container │Container│            │
│   ├──────────┼──────────┤        │  ┌─────┐  │ ┌─────┐ │            │
│   │ Deps A   │  Deps B  │        │  │App 1│  │ │App 2│ │            │
│   │ Deps C   │  Deps D  │        │  │Deps │  │ │Deps │ │            │
│   ├──────────┴──────────┤        │  └─────┘  │ └─────┘ │            │
│   │  Operating System   │        ├───────────┴─────────┤            │
│   ├─────────────────────┤        │   Container Runtime  │            │
│   │     Hardware        │        ├─────────────────────┤            │
│   └─────────────────────┘        │  Operating System   │            │
│                                  ├─────────────────────┤            │
│   ❌ Dependency conflicts        │     Hardware        │            │
│   ❌ "Works on my machine"       └─────────────────────┘            │
│   ❌ Environment drift                                              │
│                                  ✓ Isolated dependencies            │
│                                  ✓ Consistent everywhere            │
│                                  ✓ Lightweight & fast               │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Docker for Kubernetes?

| Benefit | Description |
|---------|-------------|
| **Portability** | Same container runs locally, in CI/CD, and in EKS |
| **Isolation** | Each container has its own filesystem and network |
| **Efficiency** | Containers share the OS kernel, using less resources than VMs |
| **Reproducibility** | Dockerfile ensures consistent builds |
| **Immutability** | Container images are versioned and unchanging |

---

## Docker Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                      Docker Architecture                             │
│                                                                      │
│  ┌────────────────┐                                                  │
│  │  Docker CLI    │  ◄── You interact with Docker here              │
│  └───────┬────────┘                                                  │
│          │                                                           │
│          │ REST API                                                  │
│          ▼                                                           │
│  ┌────────────────┐                                                  │
│  │  Docker Daemon │  ◄── dockerd - manages containers               │
│  │   (dockerd)    │                                                  │
│  └───────┬────────┘                                                  │
│          │                                                           │
│          ▼                                                           │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                    Docker Objects                           │     │
│  │                                                             │     │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │     │
│  │   │  Images  │  │Containers│  │ Volumes  │  │ Networks │   │     │
│  │   └──────────┘  └──────────┘  └──────────┘  └──────────┘   │     │
│  └────────────────────────────────────────────────────────────┘     │
│          │                                                           │
│          ▼                                                           │
│  ┌────────────────┐                                                  │
│  │    Registry    │  ◄── Docker Hub, ECR, GCR                       │
│  │  (Image Store) │                                                  │
│  └────────────────┘                                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Core Concepts

### Images
An image is a read-only template with instructions for creating a container.

```bash
# List local images
docker images

# Pull an image
docker pull nginx:1.25

# Remove an image
docker rmi nginx:1.25
```

### Containers
A container is a runnable instance of an image.

```bash
# Run a container
docker run -d -p 8080:80 --name my-nginx nginx:1.25

# List running containers
docker ps

# List all containers
docker ps -a

# Stop a container
docker stop my-nginx

# Remove a container
docker rm my-nginx
```

### Volumes
Volumes persist data beyond container lifecycle.

```bash
# Create a volume
docker volume create my-data

# Run container with volume
docker run -d -v my-data:/app/data my-app

# List volumes
docker volume ls
```

### Networks
Networks enable container communication.

```bash
# Create a network
docker network create my-network

# Run container on network
docker run -d --network my-network --name app my-app

# List networks
docker network ls
```

---

## Dockerfile Best Practices

### Basic Dockerfile Structure

```dockerfile
# Base image
FROM python:3.11-slim

# Metadata
LABEL maintainer="dev@example.com"

# Set working directory
WORKDIR /app

# Copy dependency file first (for caching)
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Set environment variables
ENV PYTHONUNBUFFERED=1

# Run command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Best Practices

```dockerfile
# ✓ Use specific version tags (not 'latest')
FROM python:3.11-slim

# ✓ Use .dockerignore to exclude files
# Create .dockerignore file with: __pycache__, .git, .env, etc.

# ✓ Minimize layers by combining RUN commands
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

# ✓ Use non-root user for security
RUN useradd --create-home appuser
USER appuser

# ✓ Order commands by change frequency (least → most)
# Dependencies change less often than code

# ✓ Use COPY instead of ADD (unless you need extraction)
COPY requirements.txt .

# ✓ Set resource limits
# (Done in Kubernetes, not Dockerfile)
```

---

## Multi-Stage Builds

Multi-stage builds reduce final image size by separating build and runtime stages.

### Python Example (FastAPI)

```dockerfile
# ====================
# Stage 1: Builder
# ====================
FROM python:3.11-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ====================
# Stage 2: Runtime
# ====================
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Copy application code
COPY --chown=appuser:appuser . .

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Run application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Build Comparison

```bash
# Without multi-stage: ~800MB
# With multi-stage:    ~150MB
```

---

## Image Optimization

### Size Reduction Strategies

| Strategy | Description | Savings |
|----------|-------------|---------|
| **Alpine base** | Use `python:3.11-alpine` | 50-80% |
| **Slim variants** | Use `python:3.11-slim` | 40-60% |
| **Multi-stage** | Separate build/runtime | 50-70% |
| **.dockerignore** | Exclude unnecessary files | 10-30% |
| **No cache** | `--no-cache-dir` for pip | 10-20% |

### Analyze Image Size

```bash
# View image size
docker images myapp

# Inspect image layers
docker history myapp

# Use dive for detailed analysis
dive myapp
```

### .dockerignore Example

```
# Git
.git
.gitignore

# Python
__pycache__
*.pyc
*.pyo
*.egg-info
.pytest_cache
.venv
venv

# IDE
.idea
.vscode
*.swp

# Kubernetes & Terraform
k8s/
infrastructure/
*.tfstate*

# Documentation
*.md
docs/

# Environment
.env
.env.*
```

---

## Docker Commands

### Essential Commands

```bash
# ─────────────────────────────────────────────────────────────────
# BUILD
# ─────────────────────────────────────────────────────────────────
docker build -t myapp:v1 .                    # Build image
docker build -t myapp:v1 -f Dockerfile.prod . # Use specific Dockerfile
docker build --no-cache -t myapp:v1 .         # Build without cache
docker build --platform linux/amd64 -t myapp . # Build for specific platform

# ─────────────────────────────────────────────────────────────────
# RUN
# ─────────────────────────────────────────────────────────────────
docker run myapp                              # Run container
docker run -d myapp                           # Run detached (background)
docker run -p 8000:8000 myapp                 # Map ports (host:container)
docker run -e ENV_VAR=value myapp             # Set environment variable
docker run --name my-container myapp          # Name the container
docker run --rm myapp                         # Remove after exit
docker run -it myapp /bin/sh                  # Interactive shell

# ─────────────────────────────────────────────────────────────────
# MANAGE CONTAINERS
# ─────────────────────────────────────────────────────────────────
docker ps                                     # List running containers
docker ps -a                                  # List all containers
docker stop <container>                       # Stop container
docker start <container>                      # Start stopped container
docker restart <container>                    # Restart container
docker rm <container>                         # Remove container
docker rm -f <container>                      # Force remove

# ─────────────────────────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────────────────────────
docker logs <container>                       # View logs
docker logs -f <container>                    # Follow logs
docker exec -it <container> /bin/sh           # Shell into container
docker inspect <container>                    # Container details
docker top <container>                        # Running processes
docker stats                                  # Resource usage

# ─────────────────────────────────────────────────────────────────
# IMAGES
# ─────────────────────────────────────────────────────────────────
docker images                                 # List images
docker rmi <image>                            # Remove image
docker tag myapp:v1 myapp:latest              # Tag image
docker save myapp > myapp.tar                 # Export image
docker load < myapp.tar                       # Import image

# ─────────────────────────────────────────────────────────────────
# CLEANUP
# ─────────────────────────────────────────────────────────────────
docker system prune                           # Remove unused data
docker system prune -a                        # Remove all unused data
docker image prune                            # Remove unused images
docker container prune                        # Remove stopped containers
docker volume prune                           # Remove unused volumes
```

---

## Docker Compose

Docker Compose runs multi-container applications locally.

### docker-compose.yml

```yaml
version: '3.8'

services:
  app:
    build:
      context: ./app
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/mydb
    depends_on:
      - db
    volumes:
      - ./app:/app  # Development mount
    networks:
      - backend

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: mydb
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - backend

  redis:
    image: redis:7-alpine
    networks:
      - backend

volumes:
  postgres_data:

networks:
  backend:
    driver: bridge
```

### Compose Commands

```bash
# Start services
docker-compose up

# Start in background
docker-compose up -d

# Build and start
docker-compose up --build

# Stop services
docker-compose down

# Stop and remove volumes
docker-compose down -v

# View logs
docker-compose logs -f app

# Execute command
docker-compose exec app /bin/sh

# Scale service
docker-compose up -d --scale app=3
```

---

## Container Networking

### Network Modes

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Docker Network Modes                              │
│                                                                      │
│   BRIDGE (default)                                                   │
│   ┌──────────────────────────────────────────────────┐              │
│   │ docker0 bridge                                    │              │
│   │  ├── container1 (172.17.0.2)                     │              │
│   │  └── container2 (172.17.0.3)                     │              │
│   └──────────────────────────────────────────────────┘              │
│                                                                      │
│   HOST                                                               │
│   Container shares host network stack (no isolation)                 │
│   Use for: High-performance networking                               │
│                                                                      │
│   NONE                                                               │
│   Container has no network access                                    │
│   Use for: Security-sensitive workloads                              │
│                                                                      │
│   CUSTOM BRIDGE (recommended)                                        │
│   ┌──────────────────────────────────────────────────┐              │
│   │ my-network                                       │              │
│   │  ├── frontend (can reach backend by name)       │              │
│   │  └── backend (can reach db by name)             │              │
│   └──────────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
```

### Create Custom Network

```bash
# Create network
docker network create app-network

# Run containers on network
docker run -d --network app-network --name api my-api
docker run -d --network app-network --name db postgres

# Containers can communicate by name
# From 'api' container: curl http://db:5432
```

---

## Working with ECR

Amazon Elastic Container Registry (ECR) stores Docker images for EKS.

### Authentication

```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com
```

### Push Image to ECR

```bash
# Build image
docker build -t fastapi-hello .

# Tag for ECR
docker tag fastapi-hello:latest \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest

# Push to ECR
docker push \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest
```

### Pull Image from ECR

```bash
# Pull from ECR
docker pull \
  123456789012.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest
```

### ECR Lifecycle Policy

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

---

## Project Dockerfile

Our FastAPI application uses this optimized Dockerfile:

```dockerfile
# See: app/Dockerfile

# Multi-stage build for minimal image size
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim
WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

## Next Steps

Now that you understand Docker:

1. **Build the project image**: `docker build -t fastapi-hello ./app`
2. **Run locally**: `docker run -p 8000:8000 fastapi-hello`
3. **Push to ECR** for Kubernetes deployment
4. **Learn Kubernetes** to orchestrate containers: [Kubernetes Guide →](KUBERNETES.md)

---

## Further Reading

- [Docker Official Documentation](https://docs.docker.com/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Amazon ECR User Guide](https://docs.aws.amazon.com/AmazonECR/latest/userguide/)

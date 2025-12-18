# DevOps & Kubernetes Learning Roadmap

A comprehensive guide to mastering modern DevOps practices with Kubernetes on AWS EKS.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Learning Path](#learning-path)
3. [Core Technologies](#core-technologies)
4. [Advanced Topics](#advanced-topics)
5. [Prerequisites](#prerequisites)
6. [Getting Started](#getting-started)

---

## Overview

This learning roadmap guides you through building production-ready Kubernetes applications on AWS EKS. Each technology builds upon the previous, creating a complete DevOps pipeline.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DevOps Learning Roadmap                              │
│                                                                             │
│   ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐             │
│   │  Docker  │ ──►│   K8s    │ ──►│   Helm   │ ──►│  Ingress │             │
│   │          │    │   (EKS)  │    │          │    │  (NGINX) │             │
│   └──────────┘    └──────────┘    └──────────┘    └──────────┘             │
│        │               │               │               │                   │
│        ▼               ▼               ▼               ▼                   │
│   ┌──────────────────────────────────────────────────────────────────┐     │
│   │                         Terraform                                 │     │
│   │                   (Infrastructure as Code)                        │     │
│   └──────────────────────────────────────────────────────────────────┘     │
│        │               │               │               │                   │
│        ▼               ▼               ▼               ▼                   │
│   ┌──────────┐    ┌──────────┐    ┌──────────────────────────┐             │
│   │  GitHub  │ ──►│  Argo CD │    │  Prometheus + Grafana    │             │
│   │  Actions │    │ (GitOps) │    │      (Monitoring)        │             │
│   └──────────┘    └──────────┘    └──────────────────────────┘             │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────┐      │
│   │                    ADVANCED (Future)                             │      │
│   │   Service Mesh (Istio/Linkerd) • Multi-Cluster • Security        │      │
│   └─────────────────────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Learning Path

### Phase 1: Foundation (Weeks 1-2)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **Docker** | Containers, images, Dockerfiles, multi-stage builds | [Docker Guide](DOCKER.md) |
| **Kubernetes** | Pods, Deployments, Services, ConfigMaps, Namespaces | [Kubernetes Guide](KUBERNETES.md) |

### Phase 2: Infrastructure (Weeks 3-4)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **Terraform** | Infrastructure as Code, AWS resources, state management | [Terraform Guide](TERRAFORM.md) |
| **EKS** | Managed Kubernetes, node groups, IAM integration | [Kubernetes Guide](KUBERNETES.md) |

### Phase 3: Deployment (Weeks 5-6)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **Helm** | Package management, charts, templating, releases | [Helm Guide](HELM.md) |
| **Kustomize** | Overlay patterns, environment-specific configs | [Kubernetes Guide](KUBERNETES.md#kustomize) |

### Phase 4: Traffic Management (Week 7)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **NGINX Ingress** | Routing, TLS termination, load balancing | [NGINX Ingress Guide](NGINX_INGRESS.md) |

### Phase 5: CI/CD (Weeks 8-9)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **GitHub Actions** | Workflows, pipelines, automated deployments | [GitHub Actions Guide](GITHUB_ACTIONS.md) |
| **Argo CD** | GitOps, declarative deployments, sync policies | [Argo CD Guide](ARGOCD.md) |

### Phase 6: Observability (Week 10)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **Prometheus** | Metrics collection, PromQL, alerting | [Monitoring Guide](MONITORING.md) |
| **Grafana** | Dashboards, visualization, alerting | [Monitoring Guide](MONITORING.md) |

### Phase 7: Advanced (Future)

| Technology | What You'll Learn | Documentation |
|------------|-------------------|---------------|
| **Service Mesh** | Istio/Linkerd, mTLS, traffic management | Coming Soon |
| **Multi-Cluster** | Federation, cross-cluster communication | Coming Soon |
| **Security** | Pod security, network policies, RBAC | Coming Soon |

---

## Core Technologies

### 1. Docker 🐳
**Purpose**: Container runtime and image building

```bash
# Build and run locally
docker build -t myapp .
docker run -p 8000:8000 myapp
```

**Key Concepts**: Images, Containers, Dockerfile, Volumes, Networks

📖 [Full Docker Guide →](DOCKER.md)

---

### 2. Kubernetes (EKS) ☸️
**Purpose**: Container orchestration on AWS

```bash
# Deploy to cluster
kubectl apply -k k8s/overlays/dev/
kubectl get pods -n fastapi-dev
```

**Key Concepts**: Pods, Deployments, Services, ConfigMaps, Secrets

📖 [Full Kubernetes Guide →](KUBERNETES.md)

---

### 3. Helm ⎈
**Purpose**: Package manager for Kubernetes

```bash
# Install a chart
helm install myapp ./charts/myapp -f values-dev.yaml
helm upgrade myapp ./charts/myapp --set replicas=3
```

**Key Concepts**: Charts, Values, Templates, Releases, Repositories

📖 [Full Helm Guide →](HELM.md)

---

### 4. NGINX Ingress 🌐
**Purpose**: External traffic routing to services

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
spec:
  ingressClassName: nginx
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api-service
                port:
                  number: 80
```

📖 [Full NGINX Ingress Guide →](NGINX_INGRESS.md)

---

### 5. GitHub Actions 🔄
**Purpose**: CI/CD automation

```yaml
name: Deploy
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to EKS
        run: kubectl apply -k k8s/overlays/prod/
```

📖 [Full GitHub Actions Guide →](GITHUB_ACTIONS.md)

---

### 6. Argo CD 🔀
**Purpose**: GitOps continuous delivery

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
spec:
  source:
    repoURL: https://github.com/org/repo
    path: k8s/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: production
```

📖 [Full Argo CD Guide →](ARGOCD.md)

---

### 7. Prometheus + Grafana 📊
**Purpose**: Monitoring and alerting

```yaml
# Prometheus scrape config
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
```

📖 [Full Monitoring Guide →](MONITORING.md)

---

### 8. Terraform 🏗️
**Purpose**: Infrastructure as Code

```hcl
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-cluster"
  cluster_version = "1.29"
}
```

📖 [Full Terraform Guide →](TERRAFORM.md)

---

## Advanced Topics

### Service Mesh (Istio/Linkerd)
- Mutual TLS (mTLS)
- Traffic management
- Observability
- Circuit breaking
- Canary deployments

### Multi-Cluster Patterns
- Cluster federation
- Cross-cluster service discovery
- Multi-region deployments
- Disaster recovery

### Security Best Practices
- Pod Security Policies/Standards
- Network Policies
- RBAC
- Secrets management (External Secrets, Vault)
- Image scanning

---

## Prerequisites

### Required Knowledge
- Basic Linux command line
- Git version control
- Basic networking concepts (HTTP, DNS, TCP/IP)
- YAML syntax

### Required Tools
| Tool | Version | Install |
|------|---------|---------|
| Docker | 20.10+ | [docker.com](https://docs.docker.com/get-docker/) |
| kubectl | 1.29+ | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| Terraform | 1.0+ | [terraform.io](https://www.terraform.io/downloads) |
| AWS CLI | 2.x | [aws.amazon.com](https://aws.amazon.com/cli/) |
| Helm | 3.x | [helm.sh](https://helm.sh/docs/intro/install/) |

### AWS Account Setup
1. Create AWS account
2. Configure IAM user with appropriate permissions
3. Set up AWS CLI credentials:
   ```bash
   aws configure
   ```

---

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/k8s_hello_world.git
cd k8s_hello_world
```

### 2. Start with Docker
```bash
cd app
docker build -t fastapi-hello .
docker run -p 8000:8000 fastapi-hello
# Visit http://localhost:8000
```

### 3. Deploy Infrastructure
```bash
cd infrastructure/terraform
terraform init
terraform apply -var-file=environments/dev.tfvars
```

### 4. Deploy to EKS
```bash
aws eks update-kubeconfig --name fastapi-eks-dev
kubectl apply -k k8s/overlays/dev/
```

### 5. Explore Each Guide
Work through each documentation guide in order, practicing the commands and concepts.

---

## Project Documentation Index

| Document | Description |
|----------|-------------|
| [README](../README.md) | Project overview and quick start |
| [Docker](DOCKER.md) | Container fundamentals |
| [Kubernetes](KUBERNETES.md) | K8s concepts and EKS |
| [Terraform](TERRAFORM.md) | Infrastructure as Code |
| [Helm](HELM.md) | Kubernetes package management |
| [NGINX Ingress](NGINX_INGRESS.md) | Traffic routing |
| [GitHub Actions](GITHUB_ACTIONS.md) | CI/CD pipelines |
| [Argo CD](ARGOCD.md) | GitOps deployment |
| [Monitoring](MONITORING.md) | Prometheus & Grafana |
| [Deployment](DEPLOYMENT.md) | Step-by-step deployment |
| [Troubleshooting](TROUBLESHOOTING.md) | Common issues |

---

## Further Resources

### Official Documentation
- [Kubernetes Docs](https://kubernetes.io/docs/)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/)
- [Helm Docs](https://helm.sh/docs/)
- [Argo CD Docs](https://argo-cd.readthedocs.io/)

### Certifications
- [Certified Kubernetes Administrator (CKA)](https://www.cncf.io/certification/cka/)
- [Certified Kubernetes Application Developer (CKAD)](https://www.cncf.io/certification/ckad/)
- [AWS Certified Solutions Architect](https://aws.amazon.com/certification/)

### Books
- "Kubernetes: Up and Running" by Brendan Burns
- "Terraform: Up and Running" by Yevgeniy Brikman
- "The DevOps Handbook" by Gene Kim

---

*Happy Learning! 🚀*

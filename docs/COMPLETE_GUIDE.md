# Complete DevOps Architecture Guide

This comprehensive guide explains how the entire DevOps infrastructure works, from code commit to production deployment, and provides step-by-step instructions for deploying everything.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Deep Dive](#2-component-deep-dive)
3. [How Everything Connects](#3-how-everything-connects)
4. [Deployment Guide](#4-deployment-guide)
5. [Day-to-Day Operations](#5-day-to-day-operations)

---

## 1. Architecture Overview

### The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        DEVELOPER WORKFLOW                                            │
│                                                                                                      │
│   ┌──────────┐     ┌──────────┐     ┌──────────────────────────────────────────────────────────┐   │
│   │Developer │────►│  GitHub  │────►│                   GitHub Actions                         │   │
│   │ (Code)   │     │   Repo   │     │  ┌────────────┐  ┌────────────┐  ┌────────────┐         │   │
│   └──────────┘     └──────────┘     │  │ Build      │  │ Security   │  │ Push to    │         │   │
│                                      │  │ Docker     │─►│ Scan       │─►│ ECR        │         │   │
│                                      │  └────────────┘  └────────────┘  └────────────┘         │   │
│                                      └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                      │
                                                      │ Image pushed to ECR
                                                      │ Git commit triggers Argo CD
                                                      ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS CLOUD INFRASTRUCTURE                                          │
│                                                                                                      │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────────┐  │
│   │                                         VPC (10.0.0.0/16)                                     │  │
│   │                                                                                               │  │
│   │  ┌─────────────────────────────────┐    ┌─────────────────────────────────────────────────┐  │  │
│   │  │       PUBLIC SUBNETS            │    │              PRIVATE SUBNETS                    │  │  │
│   │  │                                 │    │                                                 │  │  │
│   │  │  ┌───────────────────────────┐  │    │  ┌───────────────────────────────────────────┐  │  │  │
│   │  │  │  AWS Load Balancer (ALB)  │  │    │  │           EKS CLUSTER                     │  │  │  │
│   │  │  │  - Handles HTTPS traffic  │  │    │  │                                           │  │  │  │
│   │  │  │  - SSL/TLS termination    │◄─┼────┼──┤  ┌─────────────────────────────────────┐  │  │  │  │
│   │  │  └───────────────────────────┘  │    │  │  │        NGINX Ingress Controller     │  │  │  │  │
│   │  │                                 │    │  │  │  - Path-based routing               │  │  │  │  │
│   │  │  ┌───────────────────────────┐  │    │  │  │  - Rate limiting                    │  │  │  │  │
│   │  │  │      NAT Gateway          │  │    │  │  └─────────────────────────────────────┘  │  │  │  │
│   │  │  │  - Outbound internet for  │◄─┼────┼──┤                    │                      │  │  │  │
│   │  │  │    private subnets        │  │    │  │                    ▼                      │  │  │  │
│   │  │  └───────────────────────────┘  │    │  │  ┌─────────────────────────────────────┐  │  │  │  │
│   │  │                                 │    │  │  │     Linkerd Service Mesh            │  │  │  │  │
│   │  └─────────────────────────────────┘    │  │  │  - mTLS encryption                  │  │  │  │  │
│   │                                         │  │  │  - Traffic management               │  │  │  │  │
│   │                                         │  │  └─────────────────────────────────────┘  │  │  │  │
│   │                                         │  │                    │                      │  │  │  │
│   │                                         │  │                    ▼                      │  │  │  │
│   │                                         │  │  ┌─────────────────────────────────────┐  │  │  │  │
│   │                                         │  │  │     APPLICATION PODS                │  │  │  │  │
│   │                                         │  │  │  ┌─────┐ ┌─────┐ ┌─────┐           │  │  │  │  │
│   │                                         │  │  │  │Pod 1│ │Pod 2│ │Pod 3│           │  │  │  │  │
│   │                                         │  │  │  └─────┘ └─────┘ └─────┘           │  │  │  │  │
│   │                                         │  │  └─────────────────────────────────────┘  │  │  │  │
│   │                                         │  │                                           │  │  │  │
│   │                                         │  │  ┌─────────────────────────────────────┐  │  │  │  │
│   │                                         │  │  │     OBSERVABILITY                   │  │  │  │  │
│   │                                         │  │  │  ┌──────────┐  ┌──────────┐         │  │  │  │  │
│   │                                         │  │  │  │Prometheus│  │ Grafana  │         │  │  │  │  │
│   │                                         │  │  │  └──────────┘  └──────────┘         │  │  │  │  │
│   │                                         │  │  └─────────────────────────────────────┘  │  │  │  │
│   │                                         │  │                                           │  │  │  │
│   │                                         │  │  ┌─────────────────────────────────────┐  │  │  │  │
│   │                                         │  │  │     GitOps (Argo CD)                │  │  │  │  │
│   │                                         │  │  │  - Watches Git repository           │  │  │  │  │
│   │                                         │  │  │  - Syncs desired state to cluster   │  │  │  │  │
│   │                                         │  │  └─────────────────────────────────────┘  │  │  │  │
│   │                                         │  └───────────────────────────────────────────┘  │  │  │
│   │                                         └─────────────────────────────────────────────────┘  │  │
│   └──────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                      │
│   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐                                  │
│   │       ECR        │  │  Secrets Manager │  │    CloudWatch    │                                  │
│   │ (Docker Images)  │  │   (Credentials)  │  │     (Logs)       │                                  │
│   └──────────────────┘  └──────────────────┘  └──────────────────┘                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Request Flow Explained

When a user makes a request to your application, here's exactly what happens:

```
1. USER REQUEST
   │
   │  User types: https://hello.example.com/health
   │
   ▼
2. DNS RESOLUTION
   │
   │  DNS resolves to AWS Load Balancer IP
   │
   ▼
3. AWS LOAD BALANCER (ALB/NLB)
   │
   │  - Terminates HTTPS (SSL/TLS)
   │  - Health checks backend
   │  - Routes to healthy nodes
   │
   ▼
4. NGINX INGRESS CONTROLLER
   │
   │  - Matches Host header (hello.example.com)
   │  - Applies rate limiting
   │  - Routes based on path (/)
   │  - Adds security headers
   │
   ▼
5. KUBERNETES SERVICE
   │
   │  - Load balances across pods
   │  - Service discovery via DNS
   │
   ▼
6. LINKERD PROXY (Sidecar)
   │
   │  - Establishes mTLS connection
   │  - Retries failed requests
   │  - Collects metrics
   │
   ▼
7. APPLICATION CONTAINER
   │
   │  - FastAPI handles request
   │  - Returns {"status": "healthy"}
   │
   ▼
   Response travels back through the same path
```

---

## 2. Component Deep Dive

### 2.1 Terraform Infrastructure

**What it creates:**

```
AWS Resources Created by Terraform
├── VPC
│   ├── CIDR: 10.0.0.0/16
│   ├── Public Subnets: 10.0.1.0/24, 10.0.2.0/24
│   ├── Private Subnets: 10.0.11.0/24, 10.0.12.0/24
│   ├── Internet Gateway
│   ├── NAT Gateway (for private subnet internet access)
│   └── Route Tables
│
├── EKS Cluster
│   ├── Control Plane (AWS managed)
│   ├── Managed Node Group
│   │   ├── Instance Types: t3.medium (Spot)
│   │   ├── Min: 1, Max: 5, Desired: 2
│   │   └── Disk: 30GB
│   └── Add-ons
│       ├── CoreDNS (DNS resolution)
│       ├── kube-proxy (networking)
│       ├── VPC CNI (pod networking)
│       └── EBS CSI Driver (storage)
│
├── ECR Repository
│   ├── Image scanning enabled
│   └── Lifecycle policies (keep last 30 images)
│
└── IAM Roles (IRSA)
    ├── VPC CNI Role
    ├── EBS CSI Role
    ├── Load Balancer Controller Role
    └── External DNS Role
```

**Key files:**
- `infrastructure/main.tf` - All resources
- `infrastructure/variables.tf` - Configuration options
- `infrastructure/terraform.tfvars` - Environment values

### 2.2 Helm Chart

**What it deploys:**

```
Helm Chart Components
├── Deployment
│   ├── 2-3 replicas (auto-scaled)
│   ├── Rolling update strategy
│   ├── Health probes (liveness, readiness, startup)
│   ├── Resource limits (CPU: 200m, Memory: 256Mi)
│   └── Security context (non-root, read-only fs)
│
├── Service
│   ├── Type: ClusterIP
│   ├── Port: 80 → 8000
│   └── Selector: app.kubernetes.io/name=fastapi-app
│
├── Ingress
│   ├── Class: nginx
│   ├── Host: hello.example.com
│   ├── TLS enabled
│   └── Annotations (rate limiting, SSL redirect)
│
├── HorizontalPodAutoscaler
│   ├── Min replicas: 2
│   ├── Max replicas: 10
│   ├── Target CPU: 70%
│   └── Target Memory: 80%
│
├── PodDisruptionBudget
│   └── minAvailable: 1 (for high availability)
│
├── ServiceMonitor
│   └── Prometheus scrape config
│
├── NetworkPolicy
│   ├── Allow from ingress-nginx namespace
│   ├── Allow from monitoring namespace
│   ├── Deny all other ingress
│   └── Allow DNS egress
│
└── ConfigMap
    └── Application configuration
```

**Environment-specific configurations:**

| Environment | Replicas | Resources | Auto-Sync | TLS |
|-------------|----------|-----------|-----------|-----|
| Development | 1 | 50m/64Mi | Yes | No |
| Staging | 2 | 75m/96Mi | Yes | No |
| Production | 3+ | 100m/128Mi | No (manual) | Yes |

### 2.3 GitHub Actions CI/CD

**Workflow: docker-build.yaml**

```
Trigger: Push to main/develop on app/** changes

┌─────────────────────────────────────────────────────────────────┐
│                        BUILD JOB                                 │
├─────────────────────────────────────────────────────────────────┤
│ 1. Checkout code                                                 │
│ 2. Setup Docker Buildx                                          │
│ 3. Configure AWS credentials                                     │
│ 4. Login to Amazon ECR                                          │
│ 5. Build Docker image (multi-stage)                             │
│ 6. Run Trivy security scan                                      │
│    └── Fails on CRITICAL/HIGH vulnerabilities                   │
│ 7. Push to ECR with tags:                                       │
│    ├── :latest (only on main)                                   │
│    ├── :${GIT_SHA}                                              │
│    └── :${BRANCH_NAME}                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    UPDATE DEPLOYMENT JOB                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. Determine environment (main→prod, develop→staging)          │
│ 2. Update helm/fastapi-app/values-ci.yaml with new image tag   │
│ 3. Commit and push changes                                       │
│    └── This triggers Argo CD to sync                            │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow: infrastructure.yaml**

```
Trigger: Push to main on infrastructure/** changes
         OR manual workflow_dispatch

┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    VALIDATE     │────►│      PLAN       │────►│     APPLY       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ • terraform fmt │     │ • terraform init│     │ • Download plan │
│ • terraform     │     │ • terraform plan│     │ • terraform     │
│   validate      │     │ • Post to PR    │     │   apply         │
│ • Checkov scan  │     │ • Upload        │     │ • Output values │
│                 │     │   artifact      │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 2.4 Argo CD GitOps

**How GitOps works:**

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          GIT REPOSITORY                                  │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  helm/fastapi-app/                                               │    │
│  │  ├── Chart.yaml                                                  │    │
│  │  ├── values.yaml          ◄──── Desired State (source of truth) │    │
│  │  ├── values-prod.yaml                                            │    │
│  │  └── values-ci.yaml       ◄──── Updated by CI with new image tag │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                        Argo CD polls every 3 minutes
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            ARGO CD                                       │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  1. Fetches Git repo                                             │    │
│  │  2. Renders Helm templates                                       │    │
│  │  3. Compares with cluster state                                  │    │
│  │  4. If different → SYNC (apply changes)                         │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
                              Applies manifests
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         KUBERNETES CLUSTER                               │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Deployment: fastapi-app (image: ECR:${NEW_TAG})                 │    │
│  │  Service: fastapi-app                                            │    │
│  │  Ingress: fastapi-app                                            │    │
│  │  HPA: fastapi-app                                                │    │
│  └─────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

**Application configurations:**

| Application | Namespace | Branch | Auto-Sync | Self-Heal |
|-------------|-----------|--------|-----------|-----------|
| fastapi-app-dev | development | develop | ✅ | ✅ |
| fastapi-app-staging | staging | develop | ✅ | ✅ |
| fastapi-app-prod | production | main | ❌ | ❌ |

### 2.5 Prometheus + Grafana Monitoring

**Metrics collection flow:**

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  FastAPI App    │     │   Prometheus    │     │    Grafana      │
│                 │     │                 │     │                 │
│  /metrics ──────┼────►│  Scrape every   │────►│  Visualize      │
│  endpoint       │     │  30 seconds     │     │  dashboards     │
│                 │     │                 │     │                 │
│  Metrics:       │     │  Store metrics  │     │  Alert on       │
│  • http_requests│     │  for 15 days    │     │  thresholds     │
│  • latency      │     │                 │     │                 │
│  • errors       │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        │                       ▼                       │
        │               ┌─────────────────┐             │
        │               │  AlertManager   │             │
        │               │                 │             │
        │               │  Route alerts   │─────────────┘
        │               │  to Slack/Email │
        │               │                 │
        │               └─────────────────┘
        │
        └── ServiceMonitor discovers this endpoint automatically
```

**Key dashboards:**
- Request rate by endpoint
- P50/P95/P99 latency
- Error rate (5xx responses)
- CPU/Memory usage per pod

**Alert rules:**
- `FastAPIAppDown` - Application unreachable for 5 minutes
- `FastAPIHighLatency` - P95 > 500ms for 10 minutes
- `FastAPIHighErrorRate` - Error rate > 5% for 5 minutes
- `FastAPIHighCPUUsage` - CPU > 80% for 10 minutes

### 2.6 Linkerd Service Mesh

**What Linkerd does:**

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              POD                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐  │
│  │                                                                         │  │
│  │  ┌─────────────────┐                    ┌─────────────────────────────┐│  │
│  │  │ Linkerd Proxy   │◄───── mTLS ───────►│    Application Container   ││  │
│  │  │ (Sidecar)       │                    │    (FastAPI)               ││  │
│  │  │                 │                    │                             ││  │
│  │  │ Features:       │                    │                             ││  │
│  │  │ • Encrypt all   │                    │                             ││  │
│  │  │   traffic       │                    │                             ││  │
│  │  │ • Retry failed  │                    │                             ││  │
│  │  │   requests      │                    │                             ││  │
│  │  │ • Load balance  │                    │                             ││  │
│  │  │ • Collect       │                    │                             ││  │
│  │  │   metrics       │                    │                             ││  │
│  │  └─────────────────┘                    └─────────────────────────────┘│  │
│  │         ▲                                                               │  │
│  └─────────┼───────────────────────────────────────────────────────────────┘  │
│            │                                                                   │
│            │  All traffic goes through proxy                                  │
│            │  (transparent to application)                                    │
│            │                                                                   │
└────────────┼───────────────────────────────────────────────────────────────────┘
             │
             ▼
    ┌─────────────────┐
    │ Another Pod     │
    │ (also has       │
    │ Linkerd proxy)  │
    └─────────────────┘
```

**Traffic splitting for canary deployments:**

```
                    Traffic Split
                         │
            ┌────────────┴────────────┐
            │                         │
            ▼                         ▼
    ┌───────────────┐         ┌───────────────┐
    │    STABLE     │         │    CANARY     │
    │   (90%)       │         │   (10%)       │
    │               │         │               │
    │  v1.0.0       │         │  v1.1.0       │
    └───────────────┘         └───────────────┘
```

### 2.7 Security Layers

**Defense in depth:**

```
Layer 1: NETWORK (VPC)
├── Private subnets for pods
├── NAT Gateway for outbound
└── Security Groups

Layer 2: INGRESS
├── AWS WAF (optional)
├── Rate limiting
├── TLS termination
└── NGINX security headers

Layer 3: POD NETWORK
├── Network Policies
│   ├── Default deny all
│   ├── Allow from ingress only
│   └── Allow from monitoring only
└── Linkerd mTLS

Layer 4: POD SECURITY
├── Pod Security Standards (Restricted)
├── Non-root containers
├── Read-only filesystem
└── No privilege escalation

Layer 5: SECRETS
├── External Secrets Operator
├── AWS Secrets Manager
└── Encrypted at rest

Layer 6: RBAC
├── Service Accounts
├── IRSA (IAM Roles for Service Accounts)
└── Kubernetes RBAC
```

---

## 3. How Everything Connects

### Complete Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        COMPLETE CI/CD FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────┘

Developer pushes code
         │
         ▼
┌─────────────────┐
│ GitHub (main)   │
└────────┬────────┘
         │
         │ Webhook triggers
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                        GITHUB ACTIONS                                        │
│                                                                              │
│   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐│
│   │ 1. Checkout  │──►│ 2. Build     │──►│ 3. Scan      │──►│ 4. Push ECR  ││
│   │              │   │    Docker    │   │    Trivy     │   │              ││
│   └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘│
│                                                                     │        │
│                                                                     ▼        │
│   ┌──────────────────────────────────────────────────────────────────┐      │
│   │ 5. Update values-ci.yaml with new image tag                      │      │
│   │    image.tag: abc123def                                          │      │
│   └──────────────────────────────────────────────────────────────────┘      │
│                                                                     │        │
└─────────────────────────────────────────────────────────────────────┼────────┘
                                                                      │
                                                              Git commit
                                                                      │
                                                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              ARGO CD                                         │
│                                                                              │
│   1. Detects change in Git repository                                        │
│   2. Renders Helm chart with new values                                      │
│   3. Compares with current cluster state                                     │
│   4. Applies changes (rolling update)                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KUBERNETES CLUSTER                                 │
│                                                                              │
│   1. New ReplicaSet created with new image                                   │
│   2. New pods start (with Linkerd proxy injected)                           │
│   3. Readiness probes pass                                                   │
│   4. Traffic shifts to new pods                                              │
│   5. Old pods terminated                                                     │
│                                                                              │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐                               │
│   │ Old Pod │ ──► │ New Pod │ ──► │ New Pod │  (Rolling Update)             │
│   │  (v1)   │     │  (v2)   │     │  (v2)   │                               │
│   └─────────┘     └─────────┘     └─────────┘                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            MONITORING                                        │
│                                                                              │
│   Prometheus scrapes new pods automatically                                  │
│   Grafana shows deployment metrics                                           │
│   Alerts fire if error rate increases                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Deployment Guide

### Prerequisites

Before you begin, install these tools:

```bash
# 1. AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# 2. kubectl
curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# 3. Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 4. Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# 5. Linkerd CLI
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin

# 6. Configure AWS
aws configure
# Enter: AWS Access Key ID, Secret Access Key, Region (ap-south-1)
```

### Step 1: Deploy AWS Infrastructure

```bash
cd infrastructure

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create infrastructure (takes ~15-20 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > ../terraform-outputs.txt

# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Verify cluster access
kubectl get nodes
# Should show 2 nodes in Ready state
```

### Step 2: Build and Push Docker Image

```bash
# Get ECR URL
ECR_URL=$(terraform -chdir=infrastructure output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin ${ECR_URL%/*}

# Build image
cd app
docker build -t fastapi-hello-world:latest .

# Tag and push
docker tag fastapi-hello-world:latest $ECR_URL:latest
docker push $ECR_URL:latest

# Verify
aws ecr describe-images --repository-name fastapi-hello-world
```

### Step 3: Install NGINX Ingress Controller

```bash
# Add Helm repo
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.metrics.enabled=true

# Wait for LoadBalancer
echo "Waiting for LoadBalancer..."
kubectl -n ingress-nginx get svc ingress-nginx-controller -w

# Get the hostname (press Ctrl+C after you see it)
INGRESS_HOST=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Ingress URL: $INGRESS_HOST"
```

### Step 4: Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl -n argocd wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server --timeout=300s

# Get admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD Password: $ARGOCD_PASSWORD"

# Port forward (run in background or separate terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access UI at https://localhost:8080
# Username: admin
# Password: (from above)
```

### Step 5: Deploy Application

**Option A: Via Helm (direct)**

```bash
ECR_URL=$(terraform -chdir=infrastructure output -raw ecr_repository_url)

helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --create-namespace \
  -f helm/fastapi-app/values.yaml \
  -f helm/fastapi-app/values-prod.yaml \
  --set image.repository=$ECR_URL \
  --set image.tag=latest

# Verify
kubectl get pods -n production
kubectl get svc -n production
kubectl get ingress -n production
```

**Option B: Via Argo CD (GitOps)**

```bash
# Apply project
kubectl apply -f argocd/projects/hello-world.yaml

# Apply applications
kubectl apply -f argocd/applications/

# Check sync status
kubectl get applications -n argocd

# Or use Argo CD CLI
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure
argocd app list
argocd app sync fastapi-app-prod
```

### Step 6: Install Monitoring

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/prometheus-values.yaml

# Port forward Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80 &

# Access Grafana at http://localhost:3000
# Username: admin
# Password: prom-operator
```

### Step 7: Install Service Mesh

```bash
# Pre-flight check
linkerd check --pre

# Install CRDs
linkerd install --crds | kubectl apply -f -

# Install control plane
linkerd install | kubectl apply -f -

# Verify
linkerd check

# Install dashboard
linkerd viz install | kubectl apply -f -
linkerd viz check

# Inject mesh into production namespace
kubectl get deploy -n production -o yaml | linkerd inject - | kubectl apply -f -

# View dashboard
linkerd viz dashboard &
# Opens browser automatically
```

### Step 8: Test the Application

```bash
# Get ingress URL
INGRESS_HOST=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health endpoint
curl -H "Host: hello.example.com" http://$INGRESS_HOST/health

# Test root endpoint
curl -H "Host: hello.example.com" http://$INGRESS_HOST/

# Expected responses:
# {"status":"healthy"}
# {"message":"Hello World"}
```

---

## 5. Day-to-Day Operations

### Deploying New Code

```bash
# 1. Make code changes
cd app
# Edit main.py

# 2. Commit and push
git add .
git commit -m "Add new feature"
git push origin main

# 3. GitHub Actions automatically:
#    - Builds Docker image
#    - Scans for vulnerabilities
#    - Pushes to ECR
#    - Updates values-ci.yaml

# 4. Argo CD automatically syncs (for dev/staging)
#    For production, manually sync:
argocd app sync fastapi-app-prod
```

### Scaling

```bash
# Manual scaling
kubectl scale deployment fastapi-app -n production --replicas=5

# View HPA status
kubectl get hpa -n production

# HPA automatically scales based on CPU/memory
```

### Viewing Logs

```bash
# Application logs
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app -f

# All logs from all containers
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app --all-containers -f
```

### Rollback

```bash
# Via Helm
helm rollback fastapi-app 1 -n production

# Via Argo CD
argocd app rollback fastapi-app-prod 1

# View history
argocd app history fastapi-app-prod
```

### Checking Metrics

```bash
# Port forward Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Open http://localhost:3000
# Go to Dashboards → FastAPI Application Dashboard

# Or use Linkerd dashboard
linkerd viz dashboard
```

### Cleanup

```bash
# Delete application
helm uninstall fastapi-app -n production

# Delete monitoring
helm uninstall prometheus -n monitoring

# Delete Argo CD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete Linkerd
linkerd viz uninstall | kubectl delete -f -
linkerd uninstall | kubectl delete -f -

# Delete ingress
helm uninstall ingress-nginx -n ingress-nginx

# Delete infrastructure
cd infrastructure
terraform destroy -auto-approve
```

---

## Quick Reference

### Important URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Application | http://$INGRESS_HOST | - |
| Argo CD | https://localhost:8080 | admin / (from secret) |
| Grafana | http://localhost:3000 | admin / prom-operator |
| Prometheus | http://localhost:9090 | - |
| Linkerd | http://localhost:50750 | - |

### Common Commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# Check Argo CD
argocd app list
argocd app sync <app-name>

# Check Linkerd
linkerd check
linkerd viz stat deploy -n production

# View logs
kubectl logs -n <namespace> -l app=<name> -f

# Port forward
kubectl port-forward svc/<service> -n <namespace> <local>:<remote>
```

---

## Estimated Costs

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| EKS Control Plane | $73 |
| 2x t3.medium (Spot) | $20-30 |
| Application Load Balancer | $16 + data |
| NAT Gateway | $32 + data |
| ECR Storage | $1-5 |
| CloudWatch Logs | $5-10 |
| **Total** | **~$150-170** |

> **Tip**: Use Spot instances and single NAT Gateway for development to minimize costs.

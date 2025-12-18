# Complete DevOps Architecture Guide

This comprehensive guide explains how the entire DevOps infrastructure works, from code commit to production deployment, and provides step-by-step instructions for deploying everything **using GitHub Actions only**.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Deep Dive](#2-component-deep-dive)
3. [GitHub Actions Workflows](#3-github-actions-workflows)
4. [Deployment Guide (GitHub Actions)](#4-deployment-guide-github-actions)
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
│   │  │  ┌───────────────────────────┐  │    │  ┌───────────────────────────────────────────┐  │  │  │
│   │  │  │  AWS Load Balancer (ALB)  │◄─┼────┼──│           EKS CLUSTER                     │  │  │  │
│   │  │  └───────────────────────────┘  │    │  │  ┌─────────────────────────────────────┐  │  │  │  │
│   │  │  ┌───────────────────────────┐  │    │  │  │ NGINX Ingress → Linkerd → FastAPI   │  │  │  │  │
│   │  │  │      NAT Gateway          │◄─┼────┼──│  └─────────────────────────────────────┘  │  │  │  │
│   │  │  └───────────────────────────┘  │    │  │  ┌───────────────┐  ┌───────────────┐    │  │  │  │
│   │  └─────────────────────────────────┘    │  │  │ Prometheus    │  │ Argo CD       │    │  │  │  │
│   │                                         │  │  │ + Grafana     │  │ (GitOps)      │    │  │  │  │
│   │                                         │  │  └───────────────┘  └───────────────┘    │  │  │  │
│   │                                         │  └───────────────────────────────────────────┘  │  │  │
│   │                                         └─────────────────────────────────────────────────┘  │  │
│   └──────────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────────┐   │
│   │  TERRAFORM STATE MANAGEMENT                                                                  │   │
│   │  ┌─────────────────┐  ┌─────────────────┐                                                   │   │
│   │  │   S3 Bucket     │  │   DynamoDB      │  ◄── Created by Bootstrap Terraform              │   │
│   │  │ (State Storage) │  │ (State Locking) │                                                   │   │
│   │  └─────────────────┘  └─────────────────┘                                                   │   │
│   └─────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                      │
│   ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                                                │
│   │     ECR     │  │  Secrets    │  │  CloudWatch │                                                │
│   │  (Images)   │  │  Manager    │  │   (Logs)    │                                                │
│   └─────────────┘  └─────────────┘  └─────────────┘                                                │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

### Terraform State Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      TERRAFORM STATE MANAGEMENT                              │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    BOOTSTRAP MODULE                                  │    │
│  │   infrastructure/bootstrap/main.tf                                   │    │
│  │                                                                      │    │
│  │   Creates:                                                           │    │
│  │   ├── S3 Bucket (hello-world-terraform-state-XXXXXXXX)              │    │
│  │   │   ├── Versioning enabled                                        │    │
│  │   │   ├── Encryption enabled                                        │    │
│  │   │   └── Lifecycle policies                                        │    │
│  │   │                                                                  │    │
│  │   └── DynamoDB Table (hello-world-terraform-lock)                   │    │
│  │       └── For state locking                                         │    │
│  │                                                                      │    │
│  │   State: LOCAL (committed to Git or stored securely)                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              │ Outputs → backend.hcl                        │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    MAIN INFRASTRUCTURE                               │    │
│  │   infrastructure/*.tf                                                │    │
│  │                                                                      │    │
│  │   Creates:                                                           │    │
│  │   ├── VPC (subnets, NAT, IGW)                                       │    │
│  │   ├── EKS Cluster (managed node groups)                             │    │
│  │   ├── ECR Repository                                                │    │
│  │   └── IAM Roles (IRSA)                                              │    │
│  │                                                                      │    │
│  │   State: REMOTE (S3 + DynamoDB from bootstrap)                      │    │
│  │   Init: terraform init -backend-config=backend.hcl                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Component Deep Dive

### 2.1 Bootstrap Terraform

**Purpose:** Create S3 bucket and DynamoDB table for storing main infrastructure state.

**File:** `infrastructure/bootstrap/main.tf`

**What it creates:**
| Resource | Purpose |
|----------|---------|
| S3 Bucket | Store Terraform state files with versioning |
| DynamoDB Table | State locking to prevent concurrent modifications |

**Why separate?**
- The bootstrap module uses **local state** (no chicken-and-egg problem)
- Main infrastructure uses **remote state** for team collaboration
- Bootstrap state can be committed to Git (it's just resource IDs)

### 2.2 Backend Configuration

**File:** `infrastructure/backend.hcl`

```hcl
bucket         = "hello-world-terraform-state-abc12345"
key            = "eks-cluster/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
dynamodb_table = "hello-world-terraform-lock"
```

**Usage:**
```bash
terraform init -backend-config=backend.hcl
```

### 2.3 Main Infrastructure

See the [ARCHITECTURE.md](ARCHITECTURE.md) for detailed component breakdown.

---

## 3. GitHub Actions Workflows

### Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GITHUB ACTIONS WORKFLOWS                             │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 1. bootstrap.yaml                                                    │    │
│  │    Purpose: Create S3 + DynamoDB for state storage                  │    │
│  │    Trigger: Manual dispatch only (run once)                         │    │
│  │    Actions: plan → apply → update backend.hcl                       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              │ Creates backend.hcl                          │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 2. infrastructure.yaml                                               │    │
│  │    Purpose: Create VPC, EKS, ECR                                    │    │
│  │    Trigger: Manual dispatch or push to infrastructure/*             │    │
│  │    Actions: security-scan → plan → apply/destroy                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              │ Creates EKS cluster                          │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 3. docker-build.yaml                                                 │    │
│  │    Purpose: Build, scan, push Docker images                         │    │
│  │    Trigger: Push to app/* or manual dispatch                        │    │
│  │    Actions: build → scan → push ECR → update values-ci.yaml         │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                              │ Updates Helm values                          │
│                              ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 4. Argo CD (in-cluster)                                              │    │
│  │    Purpose: GitOps deployment                                        │    │
│  │    Trigger: Git changes detected                                    │    │
│  │    Actions: sync → deploy to Kubernetes                             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │ 5. security-scan.yaml                                                │    │
│  │    Purpose: Comprehensive security scanning                         │    │
│  │    Trigger: PRs, scheduled (weekly)                                 │    │
│  │    Actions: dependency scan, secret scan, IaC scan, container scan  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Workflow Details

| Workflow | Trigger | Environment | Actions |
|----------|---------|-------------|---------|
| `bootstrap.yaml` | Manual | bootstrap | plan, apply, destroy |
| `infrastructure.yaml` | Manual / Push | dev, staging, prod | plan, apply, destroy |
| `docker-build.yaml` | Push app/* | - | build, scan, push, update values |
| `security-scan.yaml` | PR / Schedule | - | Trivy, Checkov, Gitleaks |

---

## 4. Deployment Guide (GitHub Actions)

### Prerequisites

Before starting, ensure you have:

1. **GitHub repository** with this code pushed
2. **AWS Account** with appropriate permissions
3. **GitHub Secrets** configured (see below)

### Step 0: Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description | Example |
|--------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | `AKIAXXXXXXXXXXXXXXXX` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` |
| `AWS_ACCOUNT_ID` | AWS account ID | `123456789012` |

### Step 1: Run Bootstrap Workflow

This creates the S3 bucket and DynamoDB table for Terraform state.

1. Go to **Actions → Bootstrap Infrastructure**
2. Click **Run workflow**
3. Select `apply` action
4. Click **Run workflow**

```
Expected Output:
├── S3 Bucket: hello-world-terraform-state-abc12345
├── DynamoDB Table: hello-world-terraform-lock
└── backend.hcl (auto-committed to repo)
```

**This only needs to be run ONCE.**

### Step 2: Run Infrastructure Workflow

This creates VPC, EKS cluster, and ECR repository.

1. Go to **Actions → Infrastructure**
2. Click **Run workflow**
3. Select:
   - Action: `apply`
   - Environment: `dev`
4. Click **Run workflow**

```
Expected Output (after ~15-20 minutes):
├── VPC with public/private subnets
├── EKS Cluster (hello-world-dev-eks)
├── Managed Node Group (2 nodes)
└── ECR Repository (fastapi-hello-world)
```

### Step 3: Build and Push Docker Image

Triggered automatically when you push to `app/**`, or manually:

1. Go to **Actions → Build and Deploy**
2. Click **Run workflow**
3. Select environment: `dev`
4. Click **Run workflow**

```
Expected Output:
├── Docker image built
├── Trivy scan completed
├── Image pushed to ECR
└── values-ci.yaml updated with new tag
```

### Step 4: Install Cluster Components

After infrastructure is ready, you need to install additional components. You can do this via GitHub Actions or manually via CloudShell/local.

#### Option A: Via AWS CloudShell

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD
kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s

# Get Argo CD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Apply Argo CD applications
kubectl apply -f argocd/projects/hello-world.yaml
kubectl apply -f argocd/applications/

# Install Prometheus/Grafana (optional)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/prometheus-values.yaml

# Install Linkerd (optional)
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
```

#### Option B: Create Additional Workflow

Create `.github/workflows/cluster-setup.yaml` for full automation (advanced).

### Step 5: Verify Deployment

```bash
# Check pods
kubectl get pods -A

# Get ingress URL
kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test the application
INGRESS_URL=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -H "Host: hello-dev.example.com" http://$INGRESS_URL/health

# Check Argo CD sync status
kubectl get applications -n argocd
```

---

## 5. Day-to-Day Operations

### Deploy New Code

Simply push changes to `app/**`:

```bash
# Make changes
cd app
# Edit main.py

# Commit and push
git add .
git commit -m "Add new feature"
git push origin main
```

GitHub Actions will:
1. ✅ Build Docker image
2. ✅ Scan for vulnerabilities
3. ✅ Push to ECR
4. ✅ Update `values-ci.yaml`
5. ✅ Argo CD syncs automatically

### Scale Infrastructure

```bash
# Update terraform.tfvars
# Push to infrastructure/**

git add infrastructure/terraform.tfvars
git commit -m "Scale node group to 4 nodes"
git push origin main

# Or trigger manually via Actions
```

### Destroy Environment

1. Go to **Actions → Infrastructure**
2. Click **Run workflow**
3. Select:
   - Action: `destroy`
   - Environment: `dev`
4. Click **Run workflow**

### Destroy Bootstrap (Complete Cleanup)

**⚠️ Warning:** This deletes the S3 bucket with all Terraform state!

1. First destroy all infrastructure
2. Go to **Actions → Bootstrap Infrastructure**
3. Click **Run workflow**
4. Select `destroy` action
5. Approve the environment protection

---

## Quick Reference

### Workflow Dispatch URLs

| Workflow | URL |
|----------|-----|
| Bootstrap | `https://github.com/YOUR_ORG/k8s_hello_world/actions/workflows/bootstrap.yaml` |
| Infrastructure | `https://github.com/YOUR_ORG/k8s_hello_world/actions/workflows/infrastructure.yaml` |
| Build & Deploy | `https://github.com/YOUR_ORG/k8s_hello_world/actions/workflows/docker-build.yaml` |

### Common Commands (AWS CloudShell)

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# View pods
kubectl get pods -A

# View logs
kubectl logs -n production -l app.kubernetes.io/name=fastapi-app -f

# Argo CD status
kubectl get applications -n argocd

# Force Argo CD sync
kubectl -n argocd patch application fastapi-app-dev --type=merge -p '{"operation":{"sync":{}}}'
```

### Deployment Order

```
1. Configure GitHub Secrets
      ↓
2. Run Bootstrap Workflow (once)
      ↓
3. Run Infrastructure Workflow
      ↓
4. Install Cluster Components (CloudShell)
      ↓
5. Push code = Automatic deployment
```

---

## Estimated Costs

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| EKS Control Plane | $73 |
| 2x t3.medium (Spot) | $20-30 |
| Application Load Balancer | $16 + data |
| NAT Gateway | $32 + data |
| S3 (State Storage) | <$1 |
| DynamoDB (Locks) | <$1 |
| ECR Storage | $1-5 |
| **Total** | **~$150-170** |

# Complete DevOps Architecture Guide

This guide explains how the entire DevOps infrastructure works and how to deploy it.

---

## Deployment Flow

```
1. BOOTSTRAP (Local)        →  Run terraform locally, creates S3/DynamoDB
                            →  Auto-generates backend.hcl
2. PUSH backend.hcl         →  Commit and push to GitHub
3. INFRASTRUCTURE (GitHub)  →  Run workflow, creates VPC/EKS/ECR
4. BUILD & DEPLOY (GitHub)  →  Run workflow, builds Docker, pushes to ECR
5. CLUSTER SETUP (CloudShell) → Install NGINX, Argo CD, etc.
6. ARGO CD                  →  Syncs application automatically
```

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS CLOUD                                       │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        VPC (10.0.0.0/16)                               │ │
│  │                                                                         │ │
│  │  ┌─────────────────────┐    ┌────────────────────────────────────────┐ │ │
│  │  │   PUBLIC SUBNETS    │    │           PRIVATE SUBNETS              │ │ │
│  │  │                     │    │                                        │ │ │
│  │  │  • Load Balancer    │    │  ┌────────────────────────────────┐   │ │ │
│  │  │  • NAT Gateway      │◄───┤  │         EKS CLUSTER            │   │ │ │
│  │  │                     │    │  │                                │   │ │ │
│  │  └─────────────────────┘    │  │  • NGINX Ingress               │   │ │ │
│  │                              │  │  • Linkerd (mTLS)              │   │ │ │
│  │                              │  │  • FastAPI Pods                │   │ │ │
│  │                              │  │  • Prometheus/Grafana          │   │ │ │
│  │                              │  │  • Argo CD                     │   │ │ │
│  │                              │  │                                │   │ │ │
│  │                              │  └────────────────────────────────┘   │ │ │
│  │                              └────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │  TERRAFORM STATE                                                        ││
│  │  ┌───────────────────┐  ┌───────────────────┐                          ││
│  │  │ S3 Bucket (State) │  │ DynamoDB (Locks)  │  ← Created by bootstrap  ││
│  │  └───────────────────┘  └───────────────────┘                          ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                         │
│  │     ECR     │  │  Secrets    │  │  CloudWatch │                         │
│  │  (Images)   │  │  Manager    │  │   (Logs)    │                         │
│  └─────────────┘  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Terraform State Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    BOOTSTRAP (Run Locally)                       │
│  infrastructure/bootstrap/main.tf                                │
│                                                                  │
│  Creates:                                                        │
│  ├── S3 Bucket (hello-world-terraform-state-XXXXXXXX)           │
│  ├── DynamoDB Table (hello-world-terraform-lock)                │
│  └── backend.hcl (auto-generated)                               │
│                                                                  │
│  State: LOCAL (terraform.tfstate in bootstrap folder)           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ backend.hcl pushed to GitHub
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                MAIN INFRASTRUCTURE (GitHub Actions)              │
│  infrastructure/*.tf                                             │
│                                                                  │
│  Creates:                                                        │
│  ├── VPC (subnets, NAT, IGW)                                    │
│  ├── EKS Cluster (managed node groups)                          │
│  ├── ECR Repository                                             │
│  └── IAM Roles (IRSA)                                           │
│                                                                  │
│  State: REMOTE (S3 + DynamoDB from bootstrap)                   │
│  Init: terraform init -backend-config=backend.hcl               │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. GitHub Actions Workflows

All workflows are **manual only** (workflow_dispatch):

| Workflow | Purpose | When to Run |
|----------|---------|-------------|
| `infrastructure.yaml` | Create/destroy VPC, EKS, ECR | After pushing backend.hcl |
| `docker-build.yaml` | Build image, push to ECR | When app code changes |
| `security-scan.yaml` | Security scanning | Before releases |

---

## 4. Step-by-Step Deployment

### Prerequisites

```bash
# Install locally
aws configure          # AWS CLI with credentials
terraform --version    # Terraform >= 1.6
```

### Step 1: Bootstrap (Run Locally)

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

This creates:
- S3 bucket for state storage
- DynamoDB table for locking
- `backend.hcl` file (auto-generated in infrastructure/)

### Step 2: Push to GitHub

```bash
git add infrastructure/backend.hcl
git commit -m "chore: Add backend.hcl from bootstrap"
git push origin main
```

### Step 3: Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |

### Step 4: Run Infrastructure Workflow

1. Go to **Actions → Infrastructure**
2. Click **Run workflow**
3. Select: `apply`, `dev`
4. Wait ~15-20 minutes

### Step 5: Run Build Workflow

1. Go to **Actions → Build and Deploy**
2. Click **Run workflow**
3. Select: `dev`

### Step 6: Install Cluster Components (AWS CloudShell)

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get Argo CD password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Deploy application via GitOps
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/
```

### Step 7: Verify

```bash
# Check pods
kubectl get pods -A

# Get ingress URL
kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test
curl -H "Host: hello-dev.example.com" http://<INGRESS_URL>/health
```

---

## 5. Day-to-Day Operations

### Deploy New Code

1. Go to **Actions → Build and Deploy**
2. Click **Run workflow**
3. Argo CD syncs automatically

### Scale Infrastructure

1. Edit `infrastructure/terraform.tfvars`
2. Go to **Actions → Infrastructure** → `apply`

### Destroy Environment

1. **Destroy infrastructure**: Actions → Infrastructure → `destroy`
2. **Destroy bootstrap** (locally):
   ```bash
   cd infrastructure/bootstrap
   terraform destroy
   ```

---

## 6. Cost Estimation

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| EKS Control Plane | $73 |
| 2x t3.medium (Spot) | $20-30 |
| ALB + NAT Gateway | $48 + data |
| S3 + DynamoDB | ~$2 |
| ECR Storage | $1-5 |
| **Total** | **~$150-170** |

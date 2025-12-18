# FastAPI Hello World - Production-Grade Kubernetes Deployment

A complete DevOps infrastructure for deploying a FastAPI application on AWS EKS with production-grade tooling. **All deployments are done via GitHub Actions** - no local tools required!

## 🚀 Technologies Used

| Technology | Purpose |
|------------|---------| 
| **Docker** | Container runtime with multi-stage builds |
| **Kubernetes (EKS)** | Container orchestration on AWS |
| **Helm** | Kubernetes package management |
| **NGINX Ingress** | Ingress controller for external access |
| **GitHub Actions** | CI/CD pipelines (all deployments) |
| **Argo CD** | GitOps continuous deployment |
| **Prometheus + Grafana** | Monitoring and observability |
| **Terraform** | Infrastructure as Code |
| **Linkerd** | Service mesh for mTLS and traffic management |

## 📁 Project Structure

```
k8s_hello_world/
├── app/                        # FastAPI application
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── main.py                 # Application code
│   └── requirements.txt        # Python dependencies
│
├── infrastructure/             # Terraform IaC
│   ├── bootstrap/              # S3 + DynamoDB for state (run once)
│   ├── main.tf                 # VPC, EKS, ECR resources
│   ├── backend.hcl             # Remote state configuration
│   └── terraform.tfvars        # Environment variables
│
├── helm/                       # Helm Charts
│   └── fastapi-app/
│       ├── values.yaml         # Default values
│       ├── values-ci.yaml      # CI-generated (image tags)
│       └── values-*.yaml       # Environment-specific
│
├── argocd/                     # Argo CD GitOps
├── monitoring/                 # Prometheus + Grafana
├── service-mesh/               # Linkerd
├── security/                   # Network policies, PSS
│
├── .github/workflows/          # CI/CD Pipelines
│   ├── bootstrap.yaml          # Create S3/DynamoDB (run once)
│   ├── infrastructure.yaml     # Deploy VPC/EKS/ECR
│   ├── docker-build.yaml       # Build and push images
│   └── security-scan.yaml      # Security scanning
│
└── docs/                       # Documentation
    └── COMPLETE_GUIDE.md       # 📖 Start here!
```

## 🏁 Quick Start (GitHub Actions Only)

### Step 1: Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_ACCOUNT_ID` | Your AWS account ID |

### Step 2: Run Bootstrap (Once)

Creates S3 bucket and DynamoDB table for Terraform state.

1. Go to **Actions → Bootstrap Infrastructure**
2. Click **Run workflow** → Select `apply` → Run

### Step 3: Deploy Infrastructure

Creates VPC, EKS cluster, and ECR repository.

1. Go to **Actions → Infrastructure**
2. Click **Run workflow** → Select `apply` → Run

### Step 4: Build & Deploy Application

Push code changes to `app/**` folder, or:

1. Go to **Actions → Build and Deploy**
2. Click **Run workflow** → Run

### Step 5: Install Cluster Components

Via AWS CloudShell:

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Apply GitOps configuration
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/
```

## 🔄 Deployment Flow

```
Push Code → GitHub Actions → Build Docker → Push ECR → Update values-ci.yaml → Argo CD Syncs
```

**No local deployment needed!** Just push code and GitHub Actions handles everything.

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[COMPLETE_GUIDE.md](docs/COMPLETE_GUIDE.md)** | 📖 **Start here!** Full architecture + GitHub Actions deployment |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and diagrams |
| [RUNBOOK.md](docs/RUNBOOK.md) | Operations and troubleshooting |

## 🔒 Security Features

- **Network Policies**: Zero-trust network model
- **Pod Security Standards**: Restricted security context
- **mTLS**: Automatic encryption via Linkerd
- **Secret Management**: AWS Secrets Manager integration
- **Security Scanning**: Trivy, Checkov in CI/CD

## 💰 Cost Estimation (ap-south-1)

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| EKS Control Plane | ~$73 |
| 2x t3.medium (Spot) | ~$20-30 |
| ALB + NAT Gateway | ~$48 + data |
| S3 + DynamoDB (State) | ~$2 |
| ECR Storage | ~$1-5 |
| **Total (Dev)** | **~$150-170** |

## 🧹 Cleanup

1. **Destroy Infrastructure**: Actions → Infrastructure → `destroy`
2. **Destroy Bootstrap**: Actions → Bootstrap Infrastructure → `destroy`

## 📝 License

This project is for learning purposes. Feel free to use and modify.

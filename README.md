# FastAPI Hello World on AWS EKS with Terraform

[![Terraform Apply](https://img.shields.io/badge/Terraform-Apply-623CE4?logo=terraform)](https://www.terraform.io/)
[![Docker](https://img.shields.io/badge/Docker-Build-2496ED?logo=docker)](https://www.docker.com/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?logo=kubernetes)](https://aws.amazon.com/eks/)
[![Helm](https://img.shields.io/badge/Helm-Charts-0F1689?logo=helm)](https://helm.sh/)
[![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions)](https://github.com/features/actions)
[![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-E6522C?logo=prometheus)](https://prometheus.io/)

A production-ready FastAPI Hello World application deployed on AWS EKS (Elastic Kubernetes Service) using Terraform for infrastructure as code, with complete CI/CD pipelines via GitHub Actions.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud                                  │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                         VPC                                    │  │
│  │  ┌─────────────────┐        ┌─────────────────┐               │  │
│  │  │  Public Subnet  │        │  Private Subnet │               │  │
│  │  │  ┌───────────┐  │        │  ┌───────────┐  │               │  │
│  │  │  │    NAT    │  │        │  │  EKS Node │  │               │  │
│  │  │  │  Gateway  │  │◄──────►│  │  Group    │  │               │  │
│  │  │  └───────────┘  │        │  └───────────┘  │               │  │
│  │  └─────────────────┘        └─────────────────┘               │  │
│  │                                    ▲                           │  │
│  │                                    │                           │  │
│  │  ┌─────────────────────────────────┴───────────────────────┐  │  │
│  │  │                     EKS Cluster                          │  │  │
│  │  │  ┌────────────────────────────────────────────────────┐ │  │  │
│  │  │  │  Deployment (replicas: 2-3)                        │ │  │  │
│  │  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐            │ │  │  │
│  │  │  │  │  Pod 1  │  │  Pod 2  │  │  Pod 3  │            │ │  │  │
│  │  │  │  │ FastAPI │  │ FastAPI │  │ FastAPI │            │ │  │  │
│  │  │  │  └─────────┘  └─────────┘  └─────────┘            │ │  │  │
│  │  │  └────────────────────────────────────────────────────┘ │  │  │
│  │  │                          ▲                               │  │  │
│  │  │  ┌───────────────────────┴───────────────────────────┐  │  │  │
│  │  │  │  Service (ClusterIP) - port 80 → 8000             │  │  │  │
│  │  │  └───────────────────────────────────────────────────┘  │  │  │
│  │  └──────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                       │
│  ┌─────────────┐    ┌─────────────────────────────────────────────┐  │
│  │     ECR     │    │  S3 (Terraform State) + DynamoDB (Locks)   │  │
│  │  Registry   │    │                                             │  │
│  └─────────────┘    └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                              ▲
                              │ kubectl port-forward
                              │
                    ┌─────────┴─────────┐
                    │   Local Machine   │
                    │ http://localhost  │
                    └───────────────────┘
```

## 📁 Project Structure

```
k8s_hello_world/
├── app/                              # FastAPI application
│   ├── main.py                       # Application code
│   ├── requirements.txt              # Python dependencies
│   ├── Dockerfile                    # Multi-stage Docker build
│   └── .dockerignore                 # Docker build exclusions
├── infrastructure/
│   ├── bootstrap/                    # Terraform state management
│   │   ├── main.tf                   # S3 bucket + DynamoDB table
│   │   ├── variables.tf              # Configuration variables
│   │   └── outputs.tf                # Output values
│   └── terraform/                    # EKS infrastructure
│       ├── main.tf                   # Main configuration
│       ├── vpc.tf                    # VPC and networking
│       ├── eks.tf                    # EKS cluster
│       ├── ecr.tf                    # ECR repository
│       ├── iam.tf                    # IAM roles and policies
│       ├── variables.tf              # Configuration variables
│       ├── outputs.tf                # Output values
│       └── environments/             # Environment configs
│           ├── dev.tfvars
│           ├── test.tfvars
│           └── prod.tfvars
├── k8s/                              # Kubernetes manifests
│   ├── base/                         # Base configurations
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── overlays/                     # Environment overlays
│       ├── dev/
│       ├── test/
│       └── prod/
├── .github/workflows/                # CI/CD pipelines (MANUAL TRIGGER ONLY)
│   ├── docker-build.yml              # Build & push to ECR
│   ├── terraform-plan.yml            # Plan changes
│   ├── terraform-apply.yml           # Apply infrastructure
│   ├── terraform-destroy.yml         # Destroy infrastructure
│   └── deploy.yml                    # Deploy to EKS
└── docs/                             # Documentation
    ├── LEARNING_ROADMAP.md           # 🗺️ Complete Learning Path
    ├── DOCKER.md                     # 🐳 Docker Fundamentals
    ├── KUBERNETES.md                 # ☸️ K8s Learning Guide
    ├── HELM.md                       # ⎈ Helm Package Manager
    ├── NGINX_INGRESS.md              # 🌐 Ingress Controller
    ├── GITHUB_ACTIONS.md             # 🔄 CI/CD Pipelines
    ├── ARGOCD.md                     # 🔀 GitOps with Argo CD
    ├── MONITORING.md                 # 📊 Prometheus + Grafana
    ├── TERRAFORM.md                  # 🏗️ Infrastructure as Code
    ├── DEPLOYMENT.md                 # 🚀 Deployment Guide
    └── TROUBLESHOOTING.md            # 🔧 Troubleshooting
```

## 🚀 How to Run This App

### Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| AWS CLI | 2.x | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) |
| Terraform | >= 1.0.0 | [Install Guide](https://www.terraform.io/downloads) |
| Docker | 20.10+ | [Install Guide](https://docs.docker.com/get-docker/) |
| kubectl | 1.25+ | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| Helm | 3.x | [Install Guide](https://helm.sh/docs/intro/install/) |

---

### Option 1: Run Locally (Docker Only)

```bash
# Build and run the FastAPI app locally
cd app
docker build -t fastapi-hello .
docker run -p 8000:8000 fastapi-hello

# Visit http://localhost:8000
```

---

### Option 2: Deploy to AWS EKS (Full Setup)

#### Step 1: Bootstrap Terraform State

```bash
cd infrastructure/bootstrap
terraform init
terraform apply

# Note the S3 bucket name from output
```

#### Step 2: Deploy EKS Infrastructure

```bash
cd infrastructure/terraform

# Replace YOUR_ACCOUNT_ID with your AWS account ID
terraform init \
  -backend-config="bucket=fastapi-eks-terraform-state-YOUR_ACCOUNT_ID" \
  -backend-config="key=eks/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=fastapi-eks-terraform-locks"

terraform apply -var-file=environments/dev.tfvars

# Wait 15-20 minutes for EKS cluster creation
```

#### Step 3: Build and Push Docker Image

```bash
cd app

# Login to ECR (replace YOUR_ACCOUNT_ID)
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Build and push
docker build -t fastapi-eks-dev .
docker tag fastapi-eks-dev:latest YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest
docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest
```

#### Step 4: Configure kubectl

```bash
aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1
kubectl get nodes  # Verify connection
```

#### Step 5: Deploy Application

**Option A: Deploy with Kustomize**
```bash
# Update image in k8s/overlays/dev/kustomization.yaml with your ECR URL
kubectl apply -k k8s/overlays/dev/
kubectl get pods -n fastapi-dev
```

**Option B: Deploy with Helm**
```bash
# Update image.repository in values-dev.yaml with your ECR URL
helm install fastapi ./infrastructure/helm/fastapi-app \
  -f ./infrastructure/helm/fastapi-app/values-dev.yaml \
  -n fastapi-dev --create-namespace

helm list -n fastapi-dev
```

#### Step 6: Access the Application

```bash
# Port forward to access locally
kubectl port-forward service/fastapi-service 8000:80 -n fastapi-dev

# Or for Helm deployment:
kubectl port-forward service/fastapi-fastapi-app 8000:80 -n fastapi-dev
```

Visit: **http://localhost:8000**

Expected response:
```json
{"message": "Hello World"}
```

---

### Option 3: Full Stack Deployment (Ingress + Monitoring)

#### Install NGINX Ingress Controller

```bash
kubectl apply -k k8s/ingress-nginx/
kubectl get svc -n ingress-nginx  # Get LoadBalancer URL
```

#### Install Prometheus + Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f infrastructure/monitoring/kube-prometheus-stack-values.yaml

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# Login: admin / prom-operator
```

#### Deploy with Argo CD (GitOps)

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl get pods -n argocd -w

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080 (login: admin)

# Apply Argo CD applications
kubectl apply -f infrastructure/argocd/projects/
kubectl apply -f infrastructure/argocd/applications/
```

---

### Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -k k8s/overlays/dev/
# Or: helm uninstall fastapi -n fastapi-dev

# Destroy infrastructure
cd infrastructure/terraform
terraform destroy -var-file=environments/dev.tfvars

# Delete bootstrap (optional)
cd infrastructure/bootstrap
terraform destroy
```

## 🔧 GitHub Actions Workflows

> **All workflows are MANUAL TRIGGER ONLY** - designed for learning and controlled deployments.

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `docker-build.yml` | Manual | Builds Docker image and pushes to ECR |
| `terraform-plan.yml` | Manual | Runs `terraform plan` to preview changes |
| `terraform-apply.yml` | Manual (requires confirmation) | Applies infrastructure changes |
| `terraform-destroy.yml` | Manual (double confirmation) | Destroys infrastructure |
| `deploy.yml` | Manual | Deploys application to EKS |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_ACCOUNT_ID` | Your AWS account ID |
| `AWS_REGION` | AWS region (default: ap-south-1) |

## 🌍 Environments

| Environment | Instance Type | Replicas | Capacity | Use Case |
|-------------|---------------|----------|----------|----------|
| `dev` | t3.small | 1 | SPOT | Development, testing |
| `test` | t3.medium | 2 | ON_DEMAND | QA, integration testing |
| `prod` | t3.large | 3 | ON_DEMAND | Production workloads |

## 📖 Documentation

### 🗺️ Learning Roadmap

Follow the [**Learning Roadmap**](docs/LEARNING_ROADMAP.md) for a structured path through:

| Phase | Topics | Documentation |
|-------|--------|---------------|
| 1. Foundation | Docker, Kubernetes | [Docker](docs/DOCKER.md), [Kubernetes](docs/KUBERNETES.md) |
| 2. Infrastructure | Terraform, EKS | [Terraform](docs/TERRAFORM.md) |
| 3. Deployment | Helm, Kustomize | [Helm](docs/HELM.md) |
| 4. Traffic | NGINX Ingress | [NGINX Ingress](docs/NGINX_INGRESS.md) |
| 5. CI/CD | GitHub Actions, Argo CD | [GitHub Actions](docs/GITHUB_ACTIONS.md), [Argo CD](docs/ARGOCD.md) |
| 6. Observability | Prometheus, Grafana | [Monitoring](docs/MONITORING.md) |

### Reference Guides

- [Deployment Guide](docs/DEPLOYMENT.md) - Step-by-step deployment instructions
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions

## 💰 Cost Considerations

- **EKS Control Plane**: ~$0.10/hour ($73/month)
- **EC2 Instances**: Varies by instance type and count
- **NAT Gateway**: ~$0.045/hour + data processing
- **ECR Storage**: First 500MB free, then $0.10/GB

> **Tip**: Use `terraform-destroy.yml` workflow to destroy infrastructure when not in use.

## 📄 License

MIT License - See LICENSE for details.
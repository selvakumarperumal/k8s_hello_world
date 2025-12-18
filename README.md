# FastAPI Hello World - Production-Grade Kubernetes Deployment

A complete DevOps infrastructure for deploying a FastAPI application on AWS EKS with production-grade tooling.

## 🚀 Technologies Used

| Technology | Purpose |
|------------|---------|
| **Docker** | Container runtime with multi-stage builds |
| **Kubernetes (EKS)** | Container orchestration on AWS |
| **Helm** | Kubernetes package management |
| **NGINX Ingress** | Ingress controller for external access |
| **GitHub Actions** | CI/CD pipelines |
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
│   ├── main.tf                 # VPC, EKS, ECR resources
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   ├── versions.tf             # Provider versions
│   └── terraform.tfvars        # Environment configuration
│
├── helm/                       # Helm Charts
│   └── fastapi-app/
│       ├── Chart.yaml          # Chart metadata
│       ├── values.yaml         # Default values
│       ├── values-*.yaml       # Environment-specific values
│       └── templates/          # Kubernetes manifests
│
├── argocd/                     # Argo CD GitOps
│   ├── applications/           # Application manifests
│   ├── projects/               # AppProject definitions
│   └── install/                # Argo CD Helm values
│
├── monitoring/                 # Observability
│   ├── prometheus-values.yaml  # Prometheus configuration
│   ├── dashboards/             # Grafana dashboards
│   └── alerts/                 # Alert rules
│
├── service-mesh/               # Linkerd Service Mesh
│   ├── linkerd-values.yaml     # Linkerd configuration
│   └── policies/               # Authorization & traffic policies
│
├── security/                   # Security Configurations
│   ├── network-policies/       # Network segmentation
│   ├── pod-security/           # Pod Security Standards
│   └── secrets/                # External Secrets integration
│
├── .github/workflows/          # CI/CD Pipelines
│   ├── docker-build.yaml       # Build and push images
│   ├── infrastructure.yaml     # Terraform deployment
│   └── security-scan.yaml      # Security scanning
│
└── docs/                       # Documentation
    ├── DEPLOYMENT.md           # Step-by-step guide
    ├── ARCHITECTURE.md         # System architecture
    └── RUNBOOK.md              # Operations manual
```

## 🏁 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl, helm, terraform installed
- Docker for local builds

### 1. Deploy Infrastructure

```bash
cd infrastructure
terraform init
terraform apply -auto-approve
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks
```

### 2. Build and Push Docker Image

```bash
# Login to ECR
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin $(terraform output -raw ecr_repository_url)

# Build and push
docker build -t $(terraform output -raw ecr_repository_url):latest ./app
docker push $(terraform output -raw ecr_repository_url):latest
```

### 3. Deploy Application

```bash
# Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

# Deploy with Helm
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production --create-namespace \
  --set image.repository=$(terraform output -raw ecr_repository_url)
```

### 4. Access the Application

```bash
# Get ingress URL
kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Test
curl -H "Host: hello.example.com" http://<INGRESS_URL>/health
```

## 📊 Monitoring

```bash
# Install Prometheus/Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Access Grafana (admin/prom-operator)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

## 🔒 Security Features

- **Network Policies**: Zero-trust network model
- **Pod Security Standards**: Restricted security context
- **mTLS**: Automatic encryption via Linkerd
- **Secret Management**: AWS Secrets Manager integration
- **Security Scanning**: Trivy, Checkov in CI/CD

## 📚 Documentation

| Document | Description |
|----------|-------------|
| **[COMPLETE_GUIDE.md](docs/COMPLETE_GUIDE.md)** | 📖 **Start here!** Full architecture explanation + deployment |
| [DEPLOYMENT.md](docs/DEPLOYMENT.md) | Step-by-step deployment commands |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and diagrams |
| [RUNBOOK.md](docs/RUNBOOK.md) | Operations and troubleshooting |

## 🏷️ Environments

| Environment | Namespace | Branch | Auto-Sync |
|-------------|-----------|--------|-----------|
| Development | `development` | `develop` | ✅ |
| Staging | `staging` | `develop` | ✅ |
| Production | `production` | `main` | ❌ (Manual) |

## 💰 Cost Estimation (ap-south-1)

| Resource | Monthly Cost (USD) |
|----------|-------------------|
| EKS Control Plane | ~$73 |
| 2x t3.medium (Spot) | ~$20-30 |
| ALB | ~$16 + data |
| NAT Gateway | ~$32 + data |
| ECR Storage | ~$1-5 |
| **Total (Dev)** | **~$140-160** |

## 🧹 Cleanup

```bash
# Delete Helm releases
helm uninstall fastapi-app -n production

# Destroy infrastructure
cd infrastructure
terraform destroy -auto-approve
```

## 📝 License

This project is for learning purposes. Feel free to use and modify.

# Deployment Guide

This guide covers the complete deployment process for the FastAPI Hello World application on AWS EKS.

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/
kubectl version --client

# Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip && sudo mv terraform /usr/local/bin/
terraform version

# Linkerd CLI (for service mesh)
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
linkerd version

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64 && sudo mv argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client
```

### AWS Configuration

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify access
aws sts get-caller-identity
```

---

## Step 1: Deploy Infrastructure with Terraform

### Initialize and Apply

```bash
cd infrastructure

# Initialize Terraform (downloads providers)
terraform init

# Review the plan
terraform plan

# Apply (creates VPC, EKS, ECR)
terraform apply -auto-approve

# Get outputs
terraform output
```

### Configure kubectl

```bash
# Update kubeconfig for the new cluster
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Verify connection
kubectl get nodes
kubectl cluster-info
```

---

## Step 2: Build and Push Docker Image

### Login to ECR

```bash
# Get ECR login command
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  $(terraform -chdir=infrastructure output -raw ecr_repository_url | sed 's/\/.*//')
```

### Build and Push

```bash
cd app

# Build the image
docker build -t fastapi-hello-world:latest .

# Tag with ECR repository
ECR_URL=$(terraform -chdir=../infrastructure output -raw ecr_repository_url)
docker tag fastapi-hello-world:latest $ECR_URL:latest
docker tag fastapi-hello-world:latest $ECR_URL:$(git rev-parse --short HEAD)

# Push to ECR
docker push $ECR_URL:latest
docker push $ECR_URL:$(git rev-parse --short HEAD)
```

---

## Step 3: Install NGINX Ingress Controller

```bash
# Add Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX Ingress
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true

# Wait for LoadBalancer
kubectl -n ingress-nginx get svc ingress-nginx-controller -w

# Get the external hostname
kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## Step 4: Install Argo CD

```bash
# Create namespace
kubectl create namespace argocd

# Install Argo CD
kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl -n argocd wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Login via CLI (in another terminal)
argocd login localhost:8080 --username admin --password <password> --insecure

# Apply project and applications
kubectl apply -f argocd/projects/hello-world.yaml
kubectl apply -f argocd/applications/
```

**Access Argo CD UI:** https://localhost:8080

---

## Step 5: Deploy Application with Helm

### Option A: Direct Helm Deployment

```bash
# Get ECR URL
ECR_URL=$(terraform -chdir=infrastructure output -raw ecr_repository_url)

# Install/upgrade for development
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace development \
  --create-namespace \
  -f helm/fastapi-app/values.yaml \
  -f helm/fastapi-app/values-dev.yaml \
  --set image.repository=$ECR_URL \
  --set image.tag=latest

# For production
helm upgrade --install fastapi-app ./helm/fastapi-app \
  --namespace production \
  --create-namespace \
  -f helm/fastapi-app/values.yaml \
  -f helm/fastapi-app/values-prod.yaml \
  --set image.repository=$ECR_URL \
  --set image.tag=latest
```

### Option B: Via Argo CD (GitOps)

Argo CD will automatically sync from the Git repository. To manually sync:

```bash
argocd app sync fastapi-app-dev
argocd app sync fastapi-app-prod
```

---

## Step 6: Install Monitoring Stack

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/prometheus-values.yaml

# Port forward Grafana
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80

# Default credentials: admin / prom-operator
```

**Access Grafana:** http://localhost:3000

---

## Step 7: Install Service Mesh (Linkerd)

```bash
# Pre-flight checks
linkerd check --pre

# Install Linkerd CRDs
linkerd install --crds | kubectl apply -f -

# Install Linkerd control plane
linkerd install | kubectl apply -f -

# Verify installation
linkerd check

# Install viz extension (dashboard)
linkerd viz install | kubectl apply -f -
linkerd viz check

# Inject proxy into application (if not using annotation)
kubectl -n production get deploy fastapi-app -o yaml | \
  linkerd inject - | kubectl apply -f -

# Open dashboard
linkerd viz dashboard
```

---

## Step 8: Apply Security Policies

```bash
# Apply namespace security standards
kubectl apply -f security/pod-security/security-standards.yaml

# Apply network policies
kubectl apply -f security/network-policies/default-policies.yaml

# Install External Secrets Operator (optional)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# Apply external secrets configuration
kubectl apply -f security/secrets/external-secrets.yaml
```

---

## Step 9: Configure GitHub Actions

Add the following secrets to your GitHub repository:

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key with EKS/ECR permissions |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |
| `AWS_ACCOUNT_ID` | Your AWS account ID |

Push your code to trigger the CI/CD pipeline:

```bash
git add .
git commit -m "Add DevOps infrastructure"
git push origin main
```

---

## Step 10: Verify Deployment

```bash
# Check pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check ingress
kubectl get ingress -A

# Test health endpoint
INGRESS_HOST=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -H "Host: hello.example.com" http://$INGRESS_HOST/health

# Test root endpoint
curl -H "Host: hello.example.com" http://$INGRESS_HOST/
```

---

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Ingress not working

```bash
kubectl describe ingress <ingress-name> -n <namespace>
kubectl -n ingress-nginx logs -l app.kubernetes.io/name=ingress-nginx
```

### Argo CD sync issues

```bash
argocd app get fastapi-app-dev
argocd app diff fastapi-app-dev
```

### Terraform state issues

```bash
terraform state list
terraform refresh
```

---

## Cleanup

To destroy all resources:

```bash
# Delete Helm releases
helm uninstall fastapi-app -n production
helm uninstall prometheus -n monitoring
helm uninstall ingress-nginx -n ingress-nginx

# Delete Argo CD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Delete Linkerd
linkerd viz uninstall | kubectl delete -f -
linkerd uninstall | kubectl delete -f -

# Destroy infrastructure
cd infrastructure
terraform destroy -auto-approve
```

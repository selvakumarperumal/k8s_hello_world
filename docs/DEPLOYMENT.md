# Deployment Guide

Complete deployment instructions for the FastAPI Hello World application.

---

## Prerequisites

### Required Tools (for Bootstrap only)

```bash
# AWS CLI
aws configure

# Terraform (>= 1.6)
terraform --version
```

### GitHub Secrets Required

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |

---

## Deployment Steps

### Step 1: Bootstrap (Run Locally)

Create S3 bucket and DynamoDB table for Terraform state:

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

**Output:**
- S3 bucket: `hello-world-terraform-state-XXXXXXXX`
- DynamoDB table: `hello-world-terraform-lock`
- `backend.hcl` file auto-generated

### Step 2: Push to GitHub

```bash
git add infrastructure/backend.hcl
git commit -m "chore: Add backend.hcl from bootstrap"
git push origin main
```

### Step 3: Add GitHub Secrets

Go to **Settings → Secrets → Actions** and add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### Step 4: Run Infrastructure (GitHub Actions)

1. Go to **Actions → Infrastructure**
2. Click **Run workflow**
3. Select: Action = `apply`, Environment = `dev`
4. Wait ~15-20 minutes

### Step 5: Run Build & Deploy (GitHub Actions)

1. Go to **Actions → Build and Deploy**
2. Click **Run workflow**
3. Select: Environment = `dev`

### Step 6: Install Cluster Components (CloudShell)

```bash
# Configure kubectl
aws eks update-kubeconfig --region ap-south-1 --name hello-world-dev-eks

# Verify
kubectl get nodes

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

# Deploy GitOps apps
kubectl apply -f argocd/projects/
kubectl apply -f argocd/applications/
```

### Step 7: Verify Deployment

```bash
# Check pods
kubectl get pods -A

# Get ingress URL
INGRESS=$(kubectl -n ingress-nginx get svc ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test endpoints
curl -H "Host: hello-dev.example.com" http://$INGRESS/health
curl -H "Host: hello-dev.example.com" http://$INGRESS/
```

---

## Optional Components

### Install Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring/prometheus-values.yaml

# Access Grafana (admin/prom-operator)
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
```

### Install Linkerd (Service Mesh)

```bash
curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh
export PATH=$PATH:$HOME/.linkerd2/bin
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -
linkerd check
```

### Apply Security Policies

```bash
kubectl apply -f security/pod-security/security-standards.yaml
kubectl apply -f security/network-policies/default-policies.yaml
```

---

## Cleanup

### Destroy Infrastructure (GitHub Actions)

1. Go to **Actions → Infrastructure**
2. Click **Run workflow**
3. Select: Action = `destroy`

### Destroy Bootstrap (Local)

```bash
cd infrastructure/bootstrap
terraform destroy
```

---

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

### Terraform state issues

```bash
cd infrastructure
terraform init -backend-config=backend.hcl -reconfigure
terraform state list
```

### Argo CD sync issues

```bash
kubectl get applications -n argocd
kubectl -n argocd describe application <app-name>
```

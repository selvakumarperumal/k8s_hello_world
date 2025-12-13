# Deployment Guide

Complete guide for deploying FastAPI Hello World to AWS EKS.

## 📋 Prerequisites

- AWS CLI configured with credentials
- Terraform >= 1.0.0
- Docker
- kubectl >= 1.29
- Kustomize (included in kubectl)

## 🔐 AWS Credentials Setup

### Option 1: AWS CLI Profile

```bash
aws configure
# Enter: Access Key ID, Secret Access Key, Region (ap-south-1)
```

### Option 2: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="ap-south-1"
```

### Option 3: GitHub Actions Secrets

Add these secrets in your GitHub repository (Settings → Secrets → Actions):

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `AWS_REGION` | `ap-south-1` (or your region) |

## 🚀 Deployment Steps

### Step 1: Bootstrap State Management

```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

Note the S3 bucket name from the output.

### Step 2: Deploy Infrastructure

```bash
cd infrastructure/terraform

# Initialize with your account ID
terraform init \
  -backend-config="bucket=fastapi-eks-terraform-state-YOUR_ACCOUNT_ID" \
  -backend-config="key=eks/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=fastapi-eks-terraform-locks"

# Deploy dev environment
terraform apply -var-file=environments/dev.tfvars

# Wait 15-20 minutes for EKS cluster creation
```

### Step 3: Configure kubectl

```bash
aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1

# Verify connection
kubectl get nodes
```

### Step 4: Build and Push Docker Image

```bash
cd app

# Get ECR login
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com

# Build image
docker build -t fastapi-hello .

# Tag and push
docker tag fastapi-hello:latest \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest

docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:latest
```

### Step 5: Update Kustomize Configuration

Edit `k8s/overlays/dev/kustomization.yaml`:

```yaml
images:
  - name: fastapi-hello
    newName: YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev
    newTag: latest
```

### Step 6: Deploy to Kubernetes

```bash
# Create namespace
kubectl apply -f k8s/overlays/dev/namespace.yaml

# Deploy application
kubectl apply -k k8s/overlays/dev/

# Check deployment status
kubectl get pods -n fastapi-dev
kubectl get svc -n fastapi-dev
```

### Step 7: Access the Application

```bash
# Port forward to localhost
kubectl port-forward service/dev-fastapi-service 8000:80 -n fastapi-dev
```

Visit http://localhost:8000

## 🤖 GitHub Actions Deployment

### Using Workflows

1. **Push to main branch** → Automatically builds and pushes Docker image
2. **Create PR** → Runs Terraform plan and posts to PR
3. **Manual Terraform Apply**:
   - Go to Actions → Terraform Apply
   - Select environment (dev/test/prod)
   - Type "apply" to confirm
4. **Manual Deploy**:
   - Go to Actions → Deploy to EKS
   - Select environment and image tag

### Workflow Reference

| Workflow | When to Use |
|----------|-------------|
| Docker Build & Push | Automatic on push, or manual for specific env |
| Terraform Plan | Automatic on PR, or manual to preview changes |
| Terraform Apply | Manual - for infrastructure changes |
| Terraform Destroy | Manual - to tear down infrastructure |
| Deploy to EKS | Automatic after Docker build, or manual |

## 🔄 Switching Environments

### Deploy to Test

```bash
# Infrastructure
cd infrastructure/terraform
terraform init -reconfigure \
  -backend-config="key=eks/test/terraform.tfstate"
terraform apply -var-file=environments/test.tfvars

# Application
kubectl apply -k k8s/overlays/test/
```

### Deploy to Production

```bash
# Infrastructure
terraform init -reconfigure \
  -backend-config="key=eks/prod/terraform.tfstate"
terraform apply -var-file=environments/prod.tfvars

# Application
kubectl apply -k k8s/overlays/prod/
```

## 🧹 Cleanup

### Delete Application

```bash
kubectl delete -k k8s/overlays/dev/
kubectl delete namespace fastapi-dev
```

### Destroy Infrastructure

```bash
cd infrastructure/terraform
terraform destroy -var-file=environments/dev.tfvars
```

### Delete Bootstrap (Optional - removes state storage)

```bash
cd infrastructure/bootstrap
terraform destroy
```

## ✅ Verification Checklist

- [ ] Pods are running: `kubectl get pods -n fastapi-dev`
- [ ] Service is created: `kubectl get svc -n fastapi-dev`
- [ ] Logs are clean: `kubectl logs -l app=fastapi -n fastapi-dev`
- [ ] Health check passes: `curl http://localhost:8000/health`
- [ ] API responds: `curl http://localhost:8000`

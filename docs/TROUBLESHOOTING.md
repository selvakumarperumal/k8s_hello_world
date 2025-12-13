# Troubleshooting Guide

Common issues and solutions for FastAPI EKS deployment.

## 🔴 Terraform Issues

### Error: Backend Configuration Required

```
Error: Backend configuration changed
```

**Solution:**
```bash
terraform init -reconfigure \
  -backend-config="bucket=fastapi-eks-terraform-state-YOUR_ACCOUNT_ID" \
  -backend-config="key=eks/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=fastapi-eks-terraform-locks"
```

### Error: S3 Bucket Not Found

```
Error: Failed to get existing workspaces: S3 bucket does not exist.
```

**Solution:** Run bootstrap first:
```bash
cd infrastructure/bootstrap
terraform init
terraform apply
```

### Error: EKS Cluster Creation Timeout

**Solution:** EKS clusters take 15-20 minutes. If it fails:
```bash
# Check AWS Console for errors
# Retry the apply
terraform apply -var-file=environments/dev.tfvars
```

## 🔴 kubectl Issues

### Error: Unable to Connect to Server

```
Unable to connect to the server: dial tcp: lookup ... no such host
```

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1

# Verify
kubectl cluster-info
```

### Error: Unauthorized

```
error: You must be logged in to the server (Unauthorized)
```

**Solution:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Ensure the same credentials used for Terraform
aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1
```

## 🔴 Docker/ECR Issues

### Error: no basic auth credentials

```
Error response from daemon: no basic auth credentials
```

**Solution:**
```bash
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS --password-stdin \
  YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com
```

### Error: Repository Not Found

```
name unknown: The repository with name 'fastapi-eks-dev' does not exist
```

**Solution:** Ensure infrastructure is deployed:
```bash
cd infrastructure/terraform
terraform apply -var-file=environments/dev.tfvars
```

## 🔴 Kubernetes Deployment Issues

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n fastapi-dev

# Check pod events
kubectl describe pod <pod-name> -n fastapi-dev

# Check logs
kubectl logs <pod-name> -n fastapi-dev
```

**Common Issues:**

| Status | Cause | Solution |
|--------|-------|----------|
| ImagePullBackOff | Wrong image URL | Check ECR URL in kustomization.yaml |
| CrashLoopBackOff | App error | Check logs with `kubectl logs` |
| Pending | Resource constraints | Check node capacity |

### ImagePullBackOff

**Solution:**
1. Verify ECR image exists:
```bash
aws ecr describe-images --repository-name fastapi-eks-dev
```

2. Check nodes can access ECR:
```bash
kubectl describe pod <pod-name> -n fastapi-dev | grep -A5 Events
```

3. Verify image URL in kustomization.yaml matches ECR

### Service Not Accessible

```bash
# Check service
kubectl get svc -n fastapi-dev

# Check endpoints
kubectl get endpoints -n fastapi-dev
```

**Solution:** Ensure pods are running and selector matches

## 🔴 GitHub Actions Issues

### Workflow Fails: AWS Credentials

```
Error: Unable to locate credentials
```

**Solution:** Add GitHub secrets:
1. Go to Settings → Secrets → Actions
2. Add: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ACCOUNT_ID`

### Workflow Fails: Terraform Init

**Solution:** Ensure bootstrap is complete and secrets are correct

## 🛠️ Useful Debug Commands

```bash
# Check all resources
kubectl get all -n fastapi-dev

# Describe deployment
kubectl describe deployment dev-fastapi-deployment -n fastapi-dev

# View pod logs (follow)
kubectl logs -f -l app=fastapi -n fastapi-dev

# Exec into pod
kubectl exec -it <pod-name> -n fastapi-dev -- /bin/sh

# Check node status
kubectl get nodes -o wide

# Test service internally
kubectl run test --rm -it --image=curlimages/curl -- curl http://dev-fastapi-service.fastapi-dev.svc.cluster.local
```

## 🔁 Common Recovery Steps

### Full Reset

```bash
# 1. Delete Kubernetes resources
kubectl delete namespace fastapi-dev

# 2. Destroy infrastructure
cd infrastructure/terraform
terraform destroy -var-file=environments/dev.tfvars

# 3. Redeploy
terraform apply -var-file=environments/dev.tfvars
aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1
kubectl apply -k k8s/overlays/dev/
```

### Force Pod Restart

```bash
kubectl rollout restart deployment dev-fastapi-deployment -n fastapi-dev
```

### Update Image

```bash
# Build and push new image
docker build -t fastapi-hello ./app
docker tag fastapi-hello:latest YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:v2
docker push YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:v2

# Update deployment
kubectl set image deployment/dev-fastapi-deployment \
  fastapi=YOUR_ACCOUNT_ID.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev:v2 \
  -n fastapi-dev
```

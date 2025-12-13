# Terraform Infrastructure Guide

This guide covers the Terraform configurations for deploying FastAPI on AWS EKS.

## 📁 Structure

```
infrastructure/
├── bootstrap/           # State management (run first)
│   ├── main.tf          # S3 bucket + DynamoDB
│   ├── variables.tf
│   └── outputs.tf
└── terraform/           # EKS infrastructure
    ├── main.tf          # Providers, backend
    ├── vpc.tf           # Networking
    ├── eks.tf           # Kubernetes cluster
    ├── ecr.tf           # Container registry
    ├── iam.tf           # Permissions
    ├── variables.tf
    ├── outputs.tf
    └── environments/    # Environment configs
        ├── dev.tfvars
        ├── test.tfvars
        └── prod.tfvars
```

## 🚀 Bootstrap Setup (One-time)

The bootstrap creates S3 bucket and DynamoDB table for Terraform state management.

```bash
cd infrastructure/bootstrap
terraform init
terraform apply

# Note the outputs - you'll need them for the main infrastructure
```

**What gets created:**

| Resource | Purpose |
|----------|---------|
| S3 Bucket | Stores Terraform state files |
| DynamoDB Table | State locking (prevents concurrent modifications) |

## 🏗️ Main Infrastructure

### Initialize with Backend

After bootstrap, configure the main infrastructure:

```bash
cd infrastructure/terraform

# Replace YOUR_ACCOUNT_ID with your AWS account ID
terraform init \
  -backend-config="bucket=fastapi-eks-terraform-state-YOUR_ACCOUNT_ID" \
  -backend-config="key=eks/dev/terraform.tfstate" \
  -backend-config="region=ap-south-1" \
  -backend-config="dynamodb_table=fastapi-eks-terraform-locks"
```

### Plan Changes

```bash
terraform plan -var-file=environments/dev.tfvars
```

### Apply Changes

```bash
terraform apply -var-file=environments/dev.tfvars
```

### Destroy Infrastructure

```bash
terraform destroy -var-file=environments/dev.tfvars
```

## 🌍 Environment Configurations

### Development (`dev.tfvars`)

- **Instance Type**: t3.small (SPOT)
- **Nodes**: 1 (min: 1, max: 2)
- **Log Retention**: 3 days
- **Cost**: ~$30-50/month

### Test (`test.tfvars`)

- **Instance Type**: t3.medium (ON_DEMAND)
- **Nodes**: 2 (min: 1, max: 3)
- **Log Retention**: 7 days
- **Cost**: ~$100-150/month

### Production (`prod.tfvars`)

- **Instance Type**: t3.large (ON_DEMAND)
- **Nodes**: 3 (min: 2, max: 5)
- **Log Retention**: 30 days
- **Cost**: ~$200-300/month

## 📊 Resources Created

| Resource | Count | Description |
|----------|-------|-------------|
| VPC | 1 | Virtual Private Cloud |
| Subnets | 4 | 2 public + 2 private |
| NAT Gateway | 1-2 | Internet access for private subnets |
| EKS Cluster | 1 | Kubernetes control plane |
| Node Group | 1 | EC2 instances for pods |
| ECR Repository | 1 | Docker image storage |
| CloudWatch Log Group | 1 | Cluster logging |

## 🔧 Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_name` | string | fastapi-eks | Resource naming prefix |
| `environment` | string | dev | Environment (dev/test/prod) |
| `region` | string | ap-south-1 | AWS region |
| `vpc_cidr` | string | 10.0.0.0/16 | VPC CIDR block |
| `cluster_version` | string | 1.29 | Kubernetes version |
| `node_instance_types` | list | ["t3.medium"] | EC2 instance types |
| `node_capacity_type` | string | ON_DEMAND | ON_DEMAND or SPOT |
| `node_min_size` | number | 1 | Minimum nodes |
| `node_max_size` | number | 3 | Maximum nodes |
| `node_desired_size` | number | 2 | Desired nodes |
| `log_retention_days` | number | 7 | CloudWatch log retention |

## 📤 Outputs

After `terraform apply`, you'll get:

```hcl
cluster_name           = "fastapi-eks-dev"
cluster_endpoint       = "https://XXXXX.gr7.ap-south-1.eks.amazonaws.com"
ecr_repository_url     = "123456789012.dkr.ecr.ap-south-1.amazonaws.com/fastapi-eks-dev"
update_kubeconfig_command = "aws eks update-kubeconfig --name fastapi-eks-dev --region ap-south-1"
ecr_login_command      = "aws ecr get-login-password --region ap-south-1 | docker login ..."
```

## ⚠️ Important Notes

1. **State Management**: Always use the S3 backend for team collaboration
2. **Environment Isolation**: Each environment uses a separate state file key
3. **Cost Control**: Use SPOT instances for dev/test environments
4. **Security**: VPC uses private subnets for EKS nodes

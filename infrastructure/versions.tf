# =============================================================================
# Terraform Version and Provider Configuration
# =============================================================================
# This file defines the required Terraform version and all provider 
# configurations needed for AWS EKS infrastructure deployment.
# =============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    # AWS Provider - Primary cloud provider for EKS, VPC, ECR, etc.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Kubernetes Provider - For deploying K8s resources after cluster creation
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }

    # Helm Provider - For deploying Helm charts (NGINX Ingress, etc.)
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }

    # TLS Provider - For generating certificates
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    # Random Provider - For generating unique identifiers
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state backend configuration
  # Initialize with: terraform init -backend-config=backend.hcl
  # The backend.hcl file contains the actual bucket and table names
  backend "s3" {
    # Configuration loaded from backend.hcl file
    # bucket         = "hello-world-terraform-state-XXXXXXXX"
    # key            = "eks-cluster/terraform.tfstate"
    # region         = "ap-south-1"
    # encrypt        = true
    # dynamodb_table = "hello-world-terraform-lock"
  }
}

# =============================================================================
# Provider Configurations
# =============================================================================

# AWS Provider - Primary provider for all AWS resources
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "k8s_hello_world"
    }
  }
}

# Kubernetes Provider - Configured to use EKS cluster credentials
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider - Configured to use EKS cluster credentials
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

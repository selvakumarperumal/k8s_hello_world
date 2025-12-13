# ==============================================================================
# Terraform EKS Infrastructure - Main Configuration
# ==============================================================================
# Main Terraform configuration for AWS EKS cluster deployment.
# Uses S3 backend for remote state management.
# ==============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }

  # Backend configuration - uses bootstrap S3 bucket and DynamoDB table
  # IMPORTANT: Update these values after running bootstrap
  backend "s3" {
    bucket         = "fastapi-eks-terraform-state-ACCOUNT_ID" # Update with your account ID
    key            = "eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "fastapi-eks-terraform-locks"
    encrypt        = true
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes provider for interacting with the EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# -----------------------------------------------------------------------------
# Local Values
# -----------------------------------------------------------------------------
locals {
  cluster_name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # AZ configuration - use first 2 availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

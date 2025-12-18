# =============================================================================
# Terraform Backend Configuration
# =============================================================================
# This file configures the S3 backend for storing Terraform state.
# 
# The values here are populated after running the bootstrap module.
# Update these values with the outputs from:
#   cd infrastructure/bootstrap && terraform output
#
# Usage:
#   terraform init -backend-config=backend.hcl
# =============================================================================

bucket         = "hello-world-terraform-state-XXXXXXXX"  # Update with bootstrap output
key            = "eks-cluster/terraform.tfstate"
region         = "ap-south-1"
encrypt        = true
dynamodb_table = "hello-world-terraform-lock"            # Update with bootstrap output

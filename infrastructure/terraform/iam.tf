# ==============================================================================
# Terraform EKS Infrastructure - IAM Configuration
# ==============================================================================
# Creates IAM roles and policies for EKS and application access.
# ==============================================================================

# -----------------------------------------------------------------------------
# IAM Role for EKS Nodes to Access ECR
# -----------------------------------------------------------------------------
# Note: The EKS module already attaches the AmazonEC2ContainerRegistryReadOnly
# policy to the node group IAM role. This is sufficient for pulling images.

# -----------------------------------------------------------------------------
# IAM Role for Service Account (IRSA) - Optional for future use
# -----------------------------------------------------------------------------
# This creates an IAM role that can be assumed by a Kubernetes service account.
# Useful for giving pods specific AWS permissions without node-level access.

# module "irsa_role" {
#   source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
#   version = "~> 5.0"
#
#   role_name = "${local.cluster_name}-fastapi-role"
#
#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["default:fastapi-sa"]
#     }
#   }
#
#   role_policy_arns = {
#     # Add any AWS policies the FastAPI app needs
#   }
# }

# -----------------------------------------------------------------------------
# CloudWatch Log Group for EKS
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${local.cluster_name}-logs"
    Description = "CloudWatch log group for EKS cluster"
  }
}

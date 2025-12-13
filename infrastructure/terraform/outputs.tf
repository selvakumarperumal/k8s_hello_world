# ==============================================================================
# Terraform EKS Infrastructure - Outputs
# ==============================================================================
# Outputs useful information for accessing the cluster and deploying apps.
# ==============================================================================

# -----------------------------------------------------------------------------
# Cluster Information
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS cluster API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Version of the EKS cluster"
  value       = module.eks.cluster_version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.eks.cluster_arn
}

# -----------------------------------------------------------------------------
# ECR Information
# -----------------------------------------------------------------------------
output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.fastapi.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.fastapi.name
}

# -----------------------------------------------------------------------------
# VPC Information
# -----------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

# -----------------------------------------------------------------------------
# Helpful Commands
# -----------------------------------------------------------------------------
output "update_kubeconfig_command" {
  description = "Command to update kubeconfig for cluster access"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "ecr_login_command" {
  description = "Command to authenticate Docker with ECR"
  value       = "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "docker_push_command" {
  description = "Command to push Docker image to ECR"
  value       = "docker push ${aws_ecr_repository.fastapi.repository_url}:latest"
}

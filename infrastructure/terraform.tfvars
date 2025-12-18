# =============================================================================
# Development Environment Configuration
# =============================================================================
# Cost-optimized settings for development and testing.
# =============================================================================

project_name = "hello-world"
environment  = "dev"
aws_region   = "ap-south-1"

# VPC Configuration
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["ap-south-1a", "ap-south-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# Cost optimization: Single NAT Gateway
enable_nat_gateway = true
single_nat_gateway = true

# EKS Cluster
cluster_version                 = "1.29"
cluster_endpoint_public_access  = true
cluster_endpoint_private_access = true

# Node Group - Cost optimized with Spot instances
node_group_instance_types = ["t3.medium", "t3.small"]
node_group_desired_size   = 2
node_group_min_size       = 1
node_group_max_size       = 3
node_group_disk_size      = 30
node_group_capacity_type  = "SPOT"

# EKS Add-ons
enable_cluster_addons = true

# ECR
ecr_repository_name      = "fastapi-hello-world"
ecr_image_tag_mutability = "MUTABLE"
ecr_scan_on_push         = true

# Monitoring
enable_container_insights = false

# Additional Tags
additional_tags = {
  CostCenter = "development"
}

# ==============================================================================
# Development Environment Configuration
# ==============================================================================
# Smaller, cost-effective configuration for development.
# ==============================================================================

environment = "dev"

# VPC
vpc_cidr = "10.0.0.0/16"

# EKS
cluster_version = "1.29"

# Node group - smaller for dev
node_instance_types = ["t3.small"]
node_capacity_type  = "SPOT" # Use spot instances for cost savings in dev
node_min_size       = 1
node_max_size       = 2
node_desired_size   = 1

# Logging
log_retention_days = 3

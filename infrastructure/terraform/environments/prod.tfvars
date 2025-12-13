# ==============================================================================
# Production Environment Configuration
# ==============================================================================
# High availability configuration for production workloads.
# ==============================================================================

environment = "prod"

# VPC
vpc_cidr = "10.2.0.0/16"

# EKS
cluster_version = "1.29"

# Node group - larger for production with higher availability
node_instance_types = ["t3.large"]
node_capacity_type  = "ON_DEMAND" # Always use on-demand for production
node_min_size       = 2
node_max_size       = 5
node_desired_size   = 3

# Logging
log_retention_days = 30

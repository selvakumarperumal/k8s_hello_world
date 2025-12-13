# ==============================================================================
# Test Environment Configuration
# ==============================================================================
# Medium configuration for testing and QA.
# ==============================================================================

environment = "test"

# VPC
vpc_cidr = "10.1.0.0/16"

# EKS
cluster_version = "1.29"

# Node group - medium for test
node_instance_types = ["t3.medium"]
node_capacity_type  = "ON_DEMAND"
node_min_size       = 1
node_max_size       = 3
node_desired_size   = 2

# Logging
log_retention_days = 7

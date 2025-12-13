# ==============================================================================
# Terraform EKS Infrastructure - EKS Cluster Configuration
# ==============================================================================
# Creates the EKS cluster with managed node groups.
# Uses the official terraform-aws-modules/eks/aws module.
# ==============================================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Cluster endpoint configuration
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # VPC configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  # Managed node groups configuration
  eks_managed_node_groups = {
    default = {
      name = "${local.cluster_name}-node-group"

      instance_types = var.node_instance_types
      capacity_type  = var.node_capacity_type # ON_DEMAND or SPOT

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size

      # Node labels and taints
      labels = {
        Environment = var.environment
        NodeGroup   = "default"
      }

      # Additional security group rules
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }

      tags = {
        Name = "${local.cluster_name}-node"
      }
    }
  }

  # Enable access for the current user/role
  enable_cluster_creator_admin_permissions = true

  tags = {
    Name = local.cluster_name
  }
}

# -----------------------------------------------------------------------------
# aws-auth ConfigMap management (for additional IAM access)
# -----------------------------------------------------------------------------
# Note: The EKS module handles basic aws-auth configuration.
# Add additional mapRoles/mapUsers here if needed.

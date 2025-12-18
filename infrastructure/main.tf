# =============================================================================
# Main Terraform Configuration
# =============================================================================
# This file orchestrates all infrastructure modules and resources for the
# FastAPI Hello World application deployment on AWS EKS.
# =============================================================================

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  # Common naming prefix for all resources
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags for all resources
  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.additional_tags
  )

  # EKS cluster name
  cluster_name = "${local.name_prefix}-eks"
}

# -----------------------------------------------------------------------------
# VPC Module
# -----------------------------------------------------------------------------
# Creates a production-ready VPC with public and private subnets,
# NAT Gateways, and all required networking components for EKS.
# -----------------------------------------------------------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-vpc"
  cidr = var.vpc_cidr

  # Multi-AZ deployment for high availability
  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  private_subnets = var.private_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway

  # DNS configuration (required for EKS)
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required for EKS to discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# EKS Cluster Module
# -----------------------------------------------------------------------------
# Creates the EKS cluster with managed node groups, IAM roles,
# security groups, and all required EKS add-ons.
# -----------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  # Network configuration
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Cluster endpoint access
  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster access configuration
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Add-ons
  cluster_addons = var.enable_cluster_addons ? {
    # CoreDNS - DNS resolution within the cluster
    coredns = {
      most_recent = true
    }
    # Kube-proxy - Network proxy on each node
    kube-proxy = {
      most_recent = true
    }
    # VPC CNI - AWS VPC native networking for pods
    vpc-cni = {
      most_recent              = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
    # EBS CSI Driver - For persistent volume support
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
  } : {}

  # EKS Managed Node Group
  eks_managed_node_groups = {
    main = {
      name = "${local.name_prefix}-ng"

      # Instance configuration
      instance_types = var.node_group_instance_types
      capacity_type  = var.node_group_capacity_type
      disk_size      = var.node_group_disk_size

      # Scaling configuration
      min_size     = var.node_group_min_size
      max_size     = var.node_group_max_size
      desired_size = var.node_group_desired_size

      # Labels for node selection
      labels = {
        Environment = var.environment
        NodeGroup   = "main"
      }

      # Taints (optional - uncomment for dedicated workloads)
      # taints = [
      #   {
      #     key    = "dedicated"
      #     value  = "application"
      #     effect = "NO_SCHEDULE"
      #   }
      # ]

      # Use private subnets for worker nodes
      subnet_ids = module.vpc.private_subnets

      tags = local.common_tags
    }
  }

  # Cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
  }

  # Node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# IRSA (IAM Roles for Service Accounts)
# -----------------------------------------------------------------------------
# These modules create IAM roles that can be assumed by Kubernetes
# service accounts, enabling fine-grained AWS permissions for pods.
# -----------------------------------------------------------------------------

# VPC CNI IRSA - Required for VPC CNI add-on
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.name_prefix}-vpc-cni-irsa"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.common_tags
}

# EBS CSI Driver IRSA - Required for EBS CSI add-on
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name             = "${local.name_prefix}-ebs-csi-irsa"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.common_tags
}

# Load Balancer Controller IRSA - For AWS Load Balancer Controller
module "load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.name_prefix}-lb-controller-irsa"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

# External DNS IRSA - For External DNS controller
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                     = "${local.name_prefix}-external-dns-irsa"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/*"]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------
# Container registry for storing Docker images. Includes lifecycle
# policies for automatic cleanup of old images.
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = var.ecr_image_tag_mutability

  # Enable image scanning for security vulnerabilities
  image_scanning_configuration {
    scan_on_push = var.ecr_scan_on_push
  }

  # Encryption configuration (uses AWS managed key by default)
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

# ECR Lifecycle Policy - Clean up old images to save storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Expire untagged images older than 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Keep last 10 any-tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 50
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group for EKS
# -----------------------------------------------------------------------------
# Container Insights and control plane logging
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "eks" {
  count = var.enable_container_insights ? 1 : 0

  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 30

  tags = local.common_tags
}

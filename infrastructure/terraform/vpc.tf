# ==============================================================================
# Terraform EKS Infrastructure - VPC Configuration
# ==============================================================================
# Creates a VPC with public and private subnets for the EKS cluster.
# Uses the official terraform-aws-modules/vpc/aws module.
# ==============================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # Availability zones and subnet configuration
  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  # NAT Gateway configuration
  enable_nat_gateway   = true
  single_nat_gateway   = var.environment != "prod" # Use single NAT in non-prod for cost savings
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Required tags for EKS to discover subnets
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }

  tags = {
    Name = "${local.cluster_name}-vpc"
  }
}

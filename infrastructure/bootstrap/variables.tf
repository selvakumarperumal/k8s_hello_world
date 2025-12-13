# ==============================================================================
# Terraform Bootstrap - Variables
# ==============================================================================

variable "project_name" {
  description = "Name of the project, used for resource naming"
  type        = string
  default     = "fastapi-eks"
}

variable "region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

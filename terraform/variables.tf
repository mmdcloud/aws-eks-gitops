variable "aws_region" {
  type        = string
  description = "AWS Region to deploy resources"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "production"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "prod-eks-core"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes control plane version"
  default     = "1.31"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.100.0.0/16"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks authorized to reach the EKS public API endpoint"
  default     = ["203.0.113.0/24"] # Replace with corporate VPN/office IP
}

variable "admin_principal_arns" {
  type        = list(string)
  description = "IAM Role or User ARNs granted cluster admin privileges via Access Entries"
  default     = []
}
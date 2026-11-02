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
  default     = ["122.167.117.6/32"] # Replace with corporate VPN/office IP
}

variable "admin_principal_arns" {
  type        = list(string)
  description = "IAM Role or User ARNs granted cluster admin privileges via Access Entries"
  default     = []
}

# --- Cost Optimization Variables ---

variable "single_nat_gateway" {
  type        = bool
  description = "Use a single shared NAT Gateway across all AZs to cut NAT costs by ~66% (~$65/mo saved)"
  default     = true
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the node group (cost-efficient instances)"
  default     = ["t3.large", "t3a.large"]
}

variable "node_capacity_type" {
  type        = string
  description = "Capacity type: SPOT (up to 70-90% discount) or ON_DEMAND"
  default     = "SPOT"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "node_disk_size" {
  type        = number
  description = "Root disk size in GB for worker nodes (default 20 GB vs 100 GB reduces EBS charges)"
  default     = 20
}

variable "enable_cluster_logging" {
  type        = bool
  description = "Enable CloudWatch control plane logging (disabling saves log ingestion and retention costs)"
  default     = false
}




data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k + 4)]

  # Production high-availability egress
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Subnet tags required for AWS Load Balancer Controller auto-discovery
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = 1
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

# KMS Key for Control Plane Secrets Envelope Encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS Key for EKS secrets envelope encryption - ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/eks/${var.cluster_name}/secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Network & Endpoint Access
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidr_blocks
  cluster_endpoint_private_access      = true

  # Control Plane Logging & Encryption
  cluster_enabled_log_types              = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 90

  create_kms_key = false
  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks_secrets.arn
    resources        = ["secrets"]
  }

  # Essential Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 2
        resources = {
          limits   = { cpu = "200m", memory = "256Mi" }
          requests = { cpu = "100m", memory = "128Mi" }
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true" # Prevents IP exhaustion on dense clusters
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Modern API Authentication (EKS Access Entries)
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    for arn in var.admin_principal_arns : arn => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # Managed Node Groups Defaults (Security Hardening)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2023_x86_64_STANDARD"
    instance_types = ["m6i.xlarge", "m5.xlarge"]

    # Enforce IMDSv2 (mitigates SSRF credential exfiltration)
    metadata_options = {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = 1
    }

    # Encrypted root storage
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 100
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 125
          encrypted             = true
          delete_on_termination = true
        }
      }
    }
  }

  # Primary Production System Workload Node Group
  eks_managed_node_groups = {
    system_nodes = {
      name         = "ng-system"
      subnet_ids   = module.vpc.private_subnets
      min_size     = 3
      max_size     = 6
      desired_size = 3

      labels = {
        role = "system-critical"
      }

      taints = {
        dedicated = {
          key    = "CriticalAddonsOnly"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }

    general_workloads = {
      name         = "ng-general"
      subnet_ids   = module.vpc.private_subnets
      min_size     = 3
      max_size     = 15
      desired_size = 6

      labels = {
        role = "apps"
      }
    }
  }
}

# IAM Role for EBS CSI Driver via IRSA
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${var.cluster_name}-ebs-csi-driver"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

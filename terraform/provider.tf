terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  #   backend "s3" {
  #     bucket         = "my-company-prod-tfstate"
  #     key            = "eks/prod-cluster/terraform.tfstate"
  #     region         = "us-east-1"
  #     dynamodb_table = "tfstate-locks"
  #     encrypt        = true
  #   }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Project     = "Infrastructure"
    }
  }
}
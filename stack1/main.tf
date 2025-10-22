provider "aws" {
  region = "us-east-1"  # Updated region
}

# ------------------------
# VPC MODULE
# ------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "bedrock-poc-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ------------------------
# SECURE RANDOM PASSWORD FOR DATABASE
# ------------------------
resource "random_password" "aurora_master_password" {
  length  = 16
  special = true
  override_special = "!#$%^&*()-_=+[]{}:,.?" # excludes /, @, ", and space
}

# ------------------------
# AURORA SERVERLESS MODULE
# ------------------------
# module "aurora_serverless" {
#   source = "../modules/database"
#   cluster_identifier = "my-aurora-serverless"
#   vpc_id             = module.vpc.vpc_id
#   subnet_ids         = module.vpc.private_subnets
#   database_name       = "myapp"
#   master_username     = "dbadmin"
#   master_password     = random_password.aurora_master_password.result
#   max_capacity        = 1
#   min_capacity        = 0.5
#   allowed_cidr_blocks = ["10.0.0.0/16"]
# }

# ------------------------
# AWS ACCOUNT INFO
# ------------------------
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "bedrock-kb-${data.aws_caller_identity.current.account_id}"
}

# ------------------------
# S3 BUCKET MODULE
# ------------------------
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket        = local.bucket_name
  acl           = "private"
  force_destroy = true

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  versioning = {
    enabled = true
  }

  server_side_encryption_configuration = {
    rule = {
      apply_server_side_encryption_by_default = {
        sse_algorithm = "AES256"
      }
    }
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

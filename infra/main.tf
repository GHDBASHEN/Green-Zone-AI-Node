provider "aws" {
  region = var.region # Ensure variables.tf has default = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket = "ghdb-terraform-state-bucket" 
    key    = "green-zone/terraform.tfstate"
    region = "eu-north-1"
  }
}

# --- Module: Networking (VPC) ---
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.client_name}-vpc"
  cidr = var.vpc_cidr

  # --- FIX: Changed from us-east-1 to eu-north-1 ---
  azs             = ["eu-north-1a", "eu-north-1b"] 
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true # Good choice to save money (~$30/mo saved)
}

# --- Module: Kubernetes (EKS) ---
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.client_name}-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # GPU Node Group
  eks_managed_node_groups = {
    gpu_workers = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      # g4dn.xlarge IS available in eu-north-1, so this is correct.
      instance_types = ["t3.medium"]
      ami_type       = "AL2_x86_64"
    }
  }

  enable_cluster_creator_admin_permissions = true
}

# --- Module: IAM (Privacy) ---
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.client_name}-vpc-cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}
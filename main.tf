provider "aws" {
  region  = "eu-west-1"
}

locals {
  environment = terraform.workspace

  cluster_name_map = {
    default = "awesome"
    staging = "staging-awesome"
  }

  cluster_name = lookup(local.cluster_name_map, local.environment)

  vpc_cidr_map = {
    default = "10.0.0.0/16"
    staging = "172.16.0.0/16"
  }

  vpc_cidr = lookup(local.vpc_cidr_map, local.environment)

  vpc_subnets_map = {
    default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
    staging = cidrsubnets(local.vpc_cidr, 4, 4, 4)
  }

  vpc_subnets = lookup(local.vpc_subnets_map, local.environment)

  common_tags = {
    Environment = terraform.workspace
    Project     = "awesome"
    Owner       = "erik@erikvandam.dev"
    ManagedBy   = "Terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.44.0"

  name           = "vpc-${local.cluster_name}"
  cidr           = local.vpc_cidr
  azs            = data.aws_availability_zones.available.names
  public_subnets = local.vpc_subnets

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

resource "aws_iam_policy" "autoscaler_policy" {
  name        = "autoscaler"
  path        = "/"
  description = "Autoscaler bots are fully allowed to read/run autoscaling groups"
  policy      = file("autoscaler.json")
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"

  cluster_version = "1.16"
  cluster_name = local.cluster_name

  subnets = module.vpc.public_subnets
  vpc_id  = module.vpc.vpc_id

  # Workers
  workers_additional_policies = [
    aws_iam_policy.autoscaler_policy.arn
  ]

  worker_groups_launch_template = [
    {
      name                 = "worker-group-1"
      instance_type        = "t3.large"
      asg_desired_capacity = 1
      asg_max_size         = 2
      asg_min_size         = 1
      autoscaling_enabled  = true
      public_ip            = true
    },
  ]
}

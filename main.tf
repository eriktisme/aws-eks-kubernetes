provider "aws" {
  region  = "eu-west-1"
}

locals {
  prefix = "${var.prefix}-${terraform.workspace}"

  common_tags = {
    Environment = terraform.workspace
    Project     = var.project
    Owner       = var.contact
    ManagedBy   = "Terraform"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.44.0"

  name           = "vpc-awesome"
  cidr           = "10.0.0.0/16"
  azs            = data.aws_availability_zones.available.names
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/awesome" = "shared"
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

  cluster_name = "awesome"

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

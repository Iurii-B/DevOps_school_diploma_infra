data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name                 = "tf-vpc1"
  cidr                 = "10.10.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.10.1.0/24", "10.10.2.0/24"]
  public_subnets       = ["10.10.3.0/24", "10.10.4.0/24"]
  database_subnets     = ["10.10.5.0/24", "10.10.6.0/24"]
  #enable_nat_gateway   = true     # Not needed if we deploy nodes to Public subnets (test environment)
  #single_nat_gateway   = true     # Not needed if we deploy nodes to Public subnets (test environment)
  enable_dns_hostnames = true
  enable_dns_support   = true
  create_database_internet_gateway_route = true
  create_database_subnet_route_table = true

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  database_subnet_tags = {Name = "database-subnets-tag"}
}

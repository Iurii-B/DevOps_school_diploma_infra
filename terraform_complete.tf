variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

provider "aws" {
  region = var.region
}

locals {
  cluster_name = "tf-cluster1"
}

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
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  database_subnet_tags = {Name = "database-subnets-tag"}
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"

  cluster_name    = "${local.cluster_name}"
  cluster_version = "1.21"
  #subnets         = module.vpc.private_subnets     # Not needed if we deploy nodes to Public subnets (test environment)
  subnets         = module.vpc.public_subnets       # Nodes are deployed to Public subnets. Not good for Prod, but acceptable for Test (default EKS SGs allow only intra-cluster communication)
  
  vpc_id = module.vpc.vpc_id

  node_groups = {
    tf_ng1 = {
      desired_capacity = 2
      max_capacity         = 2
      min_capacity         = 2
      instance_types   = ["t3a.small"]
      disk_size        = "8"
    }
  }
}

resource "aws_security_group" "tf_sg1" {
  name_prefix = "tf_sg1"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"

    cidr_blocks = [
      "5.18.240.0/21",
    ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "rds_from_home"
  }
}


resource "time_sleep" "wait_60s" {
  create_duration = "60s"
  depends_on = [module.vpc.database_subnets]
}


data "aws_subnet_ids" "subnet_ids" {
    vpc_id = module.vpc.vpc_id
    depends_on = [time_sleep.wait_60s]
    tags = {Name = "database-subnets-tag"}
}

resource "aws_db_subnet_group" "database1-subnet-group" {
    name = "database1"
    subnet_ids = data.aws_subnet_ids.subnet_ids.ids
}

resource "aws_db_instance" "database1" {
    engine = "mariadb"
    engine_version = "10.4.13"
    instance_class = "db.t2.medium"
    name = "database1"
    identifier = "database1"
    username = "db_admin"
    password = "XXX"
    parameter_group_name = "default.mariadb10.4"
    db_subnet_group_name = aws_db_subnet_group.database1-subnet-group.name
    vpc_security_group_ids = [aws_security_group.tf_sg1.id]
    publicly_accessible = true
    skip_final_snapshot = true
    allocated_storage = 20
    auto_minor_version_upgrade = false
}


data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}
# To configure kubectl run "aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)"


provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  load_config_file       = false
}

resource "kubectl_manifest" "flask1-ns" {
    yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: prod
YAML
}

resource "kubectl_manifest" "flask1-deploy" {
    yaml_body = <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask1-deploy
  namespace: prod
  labels:
    app: flaskapp1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flaskapp1
  template:
    metadata:
      name: flasktemplate1
      labels:
        app: flaskapp1
    spec:
      containers:
      - image: XXX:init
        name: flaskcontainer
        env:
        - name: DB_ADMIN_USERNAME
          value: "XXX"
        - name: DB_ADMIN_PASSWORD
          value: "XXX"
        - name: DB_URL
          value: ${aws_db_instance.database1.address}/database1

YAML
}

resource "kubectl_manifest" "flask1-svc" {
    yaml_body = <<YAML
kind: Service
apiVersion: v1
metadata:
  name: flask1-lb
  namespace: prod
spec:
  type: LoadBalancer
  selector:
    app: flaskapp1
  ports:
  - protocol: TCP
    port: 5000
    targetPort: 5000
YAML
}


output "this_db_instance_address" {
    value = aws_db_instance.database1.address
}

output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.kubeconfig
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = module.eks.config_map_aws_auth
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

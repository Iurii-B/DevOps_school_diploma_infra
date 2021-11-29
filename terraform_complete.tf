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
      "XXX",
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
    username = "XXX"
    password = "XXX"
    parameter_group_name = "default.mariadb10.4"
    db_subnet_group_name = aws_db_subnet_group.database1-subnet-group.name
    vpc_security_group_ids = [aws_security_group.tf_sg1.id]
    publicly_accessible = true
    skip_final_snapshot = true
    allocated_storage = 20
    auto_minor_version_upgrade = false
}


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
          value: ${aws_db_instance.database1.password}
        - name: DB_URL
          value: ${aws_db_instance.database1.address}/database1


YAML
}

resource "kubernetes_service" "elb" {
  metadata {
    name = "terraform-elb"
    namespace = "prod"
  }
  spec {
    selector = {
      app = "flaskapp1"
    }
    port {
      port        = 5000
      target_port = 5000
    }

    type = "LoadBalancer"
  }
}


resource aws_cloudwatch_dashboard my-dashboard {
  dashboard_name = "tf-dashboard-1" 
  dashboard_body = <<JSON
{
    "widgets": [
        {
            "height": 6,
            "width": 6,
            "y": 0,
            "x": 0,
            "type": "metric",
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "FreeStorageSpace" ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${var.region}",
                "period": 300,
                "stat": "Average",
                "title": "RDS FreeStorageSpace"
            }
        },
        {
            "height": 6,
            "width": 6,
            "y": 0,
            "x": 6,
            "type": "metric",
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${module.eks.node_groups.tf_ng1.resources[0].autoscaling_groups[0].name}", { "region": "${var.region}" } ]
                ],
                "region": "${var.region}",
                "title": "NodeGroup CPUUtilization"
            }
        },
        {
            "type": "metric",
            "x": 12,
            "y": 0,
            "width": 6,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/Route53", "HealthCheckPercentageHealthy", "HealthCheckId", "${aws_route53_health_check.elb_check1.id}", { "region": "us-east-1" } ]
                ],
                "region": "${var.region}",
                "title": "ELB HealthCheck percentage",
                "period": 60,
                "stat": "Average"
            }
        }
    ]
}
JSON
}

resource "aws_route53_health_check" "elb_check1" {
  fqdn              = resource.kubernetes_service.elb.status[0].load_balancer[0].ingress[0].hostname
  port              = 5000
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = {
    Name = "tf-elb-health-check-1"
  }
}

output "route53_health_check_id" {
  value = aws_route53_health_check.elb_check1.id
}

output "asg_group" {
  value = module.eks.node_groups.tf_ng1.resources[0].autoscaling_groups[0].name
}

output "elb" {
  value = resource.kubernetes_service.elb.status[0].load_balancer[0].ingress[0].hostname
}

output "db_instance_address" {
    value = aws_db_instance.database1.address
}

output "cluster_id" {
  description = "EKS cluster ID."
  value       = module.eks.cluster_id
}

output "kubectl_config" {
  description = "kubectl config as generated by the module."
  value       = module.eks.kubeconfig
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = local.cluster_name
}

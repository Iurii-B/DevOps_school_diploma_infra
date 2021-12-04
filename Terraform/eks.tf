module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "17.24.0"
  cluster_enabled_log_types = ["api"]

  cluster_name    = "${var.cluster_name}"
  cluster_version = "1.21"
  #subnets         = module.vpc.private_subnets     # Not needed if we deploy nodes to Public subnets (test environment)
  subnets         = module.vpc.public_subnets       # Nodes are deployed to Public subnets. Not good for Prod, but acceptable for Test (default EKS SGs allow only intra-cluster communication)
  
  vpc_id = module.vpc.vpc_id

  node_groups = {
    tf_ng1 = {
      desired_capacity = 2
      max_capacity     = 2
      min_capacity     = 2
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

variable "region" {
  default     = "eu-west-1"
  description = "AWS region"
}

variable "cluster_name" {
  default = "tf-cluster1"
  description = "EKS cluster name"
}

variable "db_username" {
  description = "Database administrator username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
}


variable "k8s_namespace" {
  default = "prod"
  description = "Kubernetes namespace"
}


variable "image_init" {
  default = "XXX"
  description = "Initial application image"
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "elb" {
  description = "ELB FQDN"
  value = resource.kubernetes_service.elb.status[0].load_balancer[0].ingress[0].hostname
}

output "db_instance_address" {
  description = "RDS FQDN"
  value = aws_db_instance.database1.address
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = var.cluster_name
}

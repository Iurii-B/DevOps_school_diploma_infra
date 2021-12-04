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

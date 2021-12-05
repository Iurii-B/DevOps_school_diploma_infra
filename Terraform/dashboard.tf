resource "time_sleep" "wait_600s" {
  create_duration = "600s"
  depends_on = [kubernetes_deployment.deploy]
}

resource aws_cloudwatch_dashboard my-dashboard {
  dashboard_name = "tf-dashboard-1"
  depends_on = [time_sleep.wait_600s]
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
            "type": "metric",
            "x": 6,
            "y": 0,
            "width": 6,
            "height": 3,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "StatusCheckFailed", "AutoScalingGroupName", "${module.eks.node_groups.tf_ng1.resources[0].autoscaling_groups[0].name}"]
                ],
                "view": "singleValue",
                "region":"${var.region}",
                "title": "NodeGroup failed instances",
                "period": 300,
                "stat": "Average"
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

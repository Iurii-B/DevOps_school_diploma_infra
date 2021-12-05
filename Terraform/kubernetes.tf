provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}
# To configure kubectl run "aws eks --region $(terraform output -raw region) update-kubeconfig --name $(terraform output -raw cluster_name)"


resource "kubernetes_namespace" "ns" {
  metadata {
    name = var.k8s_namespace
  }
}


resource "kubernetes_deployment" "deploy" {

  lifecycle {
    ignore_changes = [spec,]
  }

  metadata {
    name = "flaskprod"
    namespace = var.k8s_namespace
    labels = {
      app = "flaskprod"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "flaskprod"
      }
    }

    template {
      metadata {
        labels = {
          app = "flaskprod"
        }
      }

      spec {
        container {
          image = var.image_init
          name  = "flaskprod"
        
          resources {
            limits = {
              cpu    = "500m"
              memory = "100Mi"
            }
            requests = {
              cpu    = "150m"
              memory = "50Mi"
            }
          }

          env {
              name  = "DB_ADMIN_USERNAME"
              value = var.db_username
          }
          env {
              name  = "DB_ADMIN_PASSWORD"
              value = var.db_password
          }
          env {
              name  = "DB_URL"
              value = aws_db_instance.database1.address
          }
        }  
      }
    }
  }
}

# To install Metrics Server run "kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"

resource "kubernetes_service" "elb" {

  metadata {
    name = "tf-elb"
    namespace = var.k8s_namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-access-log-enabled" = "true"
      "service.beta.kubernetes.io/aws-load-balancer-access-log-emit-interval" = "5"
      "service.beta.kubernetes.io/aws-load-balancer-access-log-s3-bucket-name" = "tf-s3-bucket-for-logs"
    }

  }

  spec {
    selector = {
      app = "flaskprod"
    }

    port {
      port        = 5000
      target_port = 5000
    }

    type = "LoadBalancer"

  }
}

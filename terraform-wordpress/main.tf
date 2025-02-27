terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path = "/home/kubicle/.kube/config"
}

# Namespace
resource "kubernetes_namespace" "wordpress" {
  metadata {
    name = "wordpress"
  }
}

# MySQL Secret
resource "kubernetes_secret" "mysql_secret" {
  metadata {
    name      = "mysql-secret"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  data = {
    MYSQL_ROOT_PASSWORD = "rootpassword"
    MYSQL_USER          = "wordpress"
    MYSQL_PASSWORD      = "wordpresspassword"
  }

  type = "Opaque"
}

# MySQL Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "mysql_pvc" {
  metadata {
    name      = "mysql-pvc"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

# MySQL StatefulSet
resource "kubernetes_stateful_set" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector {
      match_labels = {
        app = "mysql"
      }
    }

    service_name = "mysql"

    replicas = 1

    template {
      metadata {
        labels = {
          app = "mysql"
        }
      }

      spec {
        container {
          name  = "mysql"
          image = "mysql:5.7"

          env {
            name = "MYSQL_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "MYSQL_ROOT_PASSWORD"
              }
            }
          }

          env {
            name = "MYSQL_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "MYSQL_USER"
              }
            }
          }

          env {
            name = "MYSQL_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "MYSQL_PASSWORD"
              }
            }
          }

          port {
            container_port = 4306
          }

          volume_mount {
            name       = "mysql-storage"
            mount_path = "/var/lib/mysql"
          }

          readiness_probe {
            exec {
              command = ["/bin/sh", "-c", "mysqladmin ping -h 127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          liveness_probe {
            exec {
              command = ["/bin/sh", "-c", "mysqladmin ping -h 127.0.0.1 -uroot -p$MYSQL_ROOT_PASSWORD"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }

        volume {
          name = "mysql-storage"

          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mysql_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# MySQL Service
resource "kubernetes_service" "mysql" {
  metadata {
    name      = "mysql"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector = {
      app = "mysql"
    }

    port {
      port        = 4306
      target_port = 4306
    }
  }
}

# WordPress Deployment
resource "kubernetes_deployment" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "wordpress"
      }
    }

    template {
      metadata {
        labels = {
          app = "wordpress"
        }
      }

      spec {
        container {
          name  = "wordpress"
          image = "wordpress:latest"

          env {
            name  = "WORDPRESS_DB_HOST"
            value = "mysql"
          }

          env {
            name = "WORDPRESS_DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "MYSQL_USER"
              }
            }
          }

          env {
            name = "WORDPRESS_DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mysql_secret.metadata[0].name
                key  = "MYSQL_PASSWORD"
              }
            }
          }

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# WordPress Service
resource "kubernetes_service" "wordpress" {
  metadata {
    name      = "wordpress"
    namespace = kubernetes_namespace.wordpress.metadata[0].name
  }

  spec {
    selector = {
      app = "wordpress"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  # Use Terraform Cloud for remote state (optional)
  # cloud {
  #   organization = "your-org"
  #   workspaces {
  #     name = "cloud-text-analyzer"
  #   }
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

variable "image" {}

resource "google_cloud_run_service" "default" {
  name     = "my-app"
  location = "us-central1"

  template {
    spec {
      containers {
        image = var.image
      }
    }
  }
}


# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "compute.googleapis.com",
    "vpcaccess.googleapis.com"
  ])
  
  project = var.project_id
  service = each.value
  
  disable_on_destroy = false
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "app_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "text-analyzer-repo"
  description   = "Repository for text analyzer container images"
  format        = "DOCKER"
  
  depends_on = [google_project_service.apis]
}

# Create dedicated service account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  project      = var.project_id
  account_id   = "text-analyzer-run-sa"
  display_name = "Text Analyzer Cloud Run Service Account"
  description  = "Service account for text analyzer Cloud Run service"
}

# Grant minimal permissions to the service account
resource "google_project_iam_member" "cloud_run_permissions" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Create VPC network for private access
resource "google_compute_network" "vpc_network" {
  project                 = var.project_id
  name                    = "text-analyzer-vpc"
  auto_create_subnetworks = false
  description             = "VPC network for text analyzer application"
}

# Create subnet
resource "google_compute_subnetwork" "subnet" {
  project       = var.project_id
  name          = "text-analyzer-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
  
  # Enable private Google access
  private_ip_google_access = true
}

# Create VPC connector for Cloud Run
resource "google_vpc_access_connector" "connector" {
  project        = var.project_id
  name           = "text-analyzer-connector"
  region         = var.region
  ip_cidr_range  = "10.8.0.0/28"
  network        = google_compute_network.vpc_network.name
  max_throughput = 200
  
  depends_on = [google_project_service.apis]
}

# Cloud Run service
resource "google_cloud_run_v2_service" "text_analyzer" {
  project  = var.project_id
  name     = "text-analyzer"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  
  template {
    # Use the service account
    service_account = google_service_account.cloud_run_sa.email
    
    # VPC configuration
    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "PRIVATE_RANGES_ONLY"
    }
    
    # Container configuration
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/text-analyzer-repo/text-analyzer:latest"
      
      ports {
        container_port = 8000
      }
      
      # Resource limits
      resources {
        limits = {
          cpu    = "1000m"
          memory = "512Mi"
        }
        cpu_idle          = true
        startup_cpu_boost = false
      }
      
      # Environment variables
      env {
        name  = "PORT"
        value = "8000"
      }
      
      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
    
    # Scaling configuration
    scaling {
      min_instance_count = 0
      max_instance_count = 10
    }
    
    # Timeout configuration
    timeout = "300s"
  }
  
  # Traffic configuration
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
  
  depends_on = [
    google_project_service.apis,
    google_artifact_registry_repository.app_repo,
    google_vpc_access_connector.connector
  ]
}

# Create Cloud Build service account
resource "google_service_account" "cloud_build_sa" {
  project      = var.project_id
  account_id   = "text-analyzer-build-sa"
  display_name = "Text Analyzer Cloud Build Service Account"
  description  = "Service account for building and deploying text analyzer"
}

# Grant Cloud Build permissions
resource "google_project_iam_member" "cloud_build_permissions" {
  for_each = toset([
    "roles/cloudbuild.builds.builder",
    "roles/artifactregistry.writer",
    "roles/run.developer",
    "roles/iam.serviceAccountUser"
  ])
  
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Allow Cloud Build to use the Cloud Run service account
resource "google_service_account_iam_member" "cloud_build_sa_user" {
  service_account_id = google_service_account.cloud_run_sa.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# Create a firewall rule for health checks (if needed)
resource "google_compute_firewall" "allow_health_check" {
  project = var.project_id
  name    = "allow-health-check-text-analyzer"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["8000"]
  }

  # Google health check IP ranges
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["text-analyzer"]

  description = "Allow health checks for text analyzer service"
}




# locals {
#   effective_project_id = var.create_project ? google_project.project[0].project_id : var.project_id
# }

# # Optional: create a project
# resource "google_project" "project" {
#   count            = var.create_project ? 1 : 0
#   name             = var.project_id
#   project_id       = var.project_id
#   org_id           = var.org_id
#   billing_account  = var.billing_account
#   auto_create_network = false
# }

# # Enable required APIs
# resource "google_project_service" "services" {
#   for_each = toset([
#     "run.googleapis.com",
#     "artifactregistry.googleapis.com",
#     "cloudbuild.googleapis.com",
#     "iam.googleapis.com",
#     "compute.googleapis.com"
#   ])
#   project            = local.effective_project_id
#   service            = each.key
#   disable_on_destroy = false
# }

# # Artifact Registry (Docker)
# resource "google_artifact_registry_repository" "repo" {
#   provider      = google-beta
#   location      = var.region
#   repository_id = var.repo_id
#   format        = "DOCKER"
#   description   = "Container images for the text analyzer"
#   project       = local.effective_project_id
#   depends_on    = [google_project_service.services]
# }

# # Runtime service account (least privilege)
# resource "google_service_account" "run_sa" {
#   account_id   = "crun-text-analyzer"
#   display_name = "Cloud Run runtime for ${var.service_name}"
#   project      = local.effective_project_id
# }

# # Cloud Run v2 service (internal ingress + IAM-only)
# resource "google_cloud_run_v2_service" "service" {
#   name     = var.service_name
#   location = var.region
#   project  = local.effective_project_id

#   # Internal LB only (not public). Alternative: INGRESS_TRAFFIC_INTERNAL_ONLY
#   ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

#   template {
#     service_account = google_service_account.run_sa.email

#     containers {
#       image = var.image
#       ports { container_port = 8080 }
#       resources {
#         limits = {
#           cpu    = "1"
#           memory = "512Mi"
#         }
#       }
#       startup_probe {
#         http_get { path = "/healthz", port = 8080 }
#         initial_delay_seconds = 1
#         timeout_seconds       = 1
#         period_seconds        = 5
#         failure_threshold     = 3
#       }
#     }
#   }

#   # Ensure APIs are ready first
#   depends_on = [google_project_service.services]
# }

# # Do NOT grant public invoker. Instead, optionally grant a specific principal.
# # Example value for allowed_invoker:
# #   serviceAccount:my-caller@<project>.iam.gserviceaccount.com
# resource "google_cloud_run_v2_service_iam_member" "invoker" {
#   count   = var.allowed_invoker == null ? 0 : 1
#   name    = google_cloud_run_v2_service.service.name
#   project = local.effective_project_id
#   location = var.region
#   role    = "roles/run.invoker"
#   member  = var.allowed_invoker
# }

# output "cloud_run_service_name" {
#   value = google_cloud_run_v2_service.service.name
# }

# output "cloud_run_uri" {
#   # Note: URI exists but will be reachable only via Internal HTTP(S) LB.
#   value = google_cloud_run_v2_service.service.uri
# }

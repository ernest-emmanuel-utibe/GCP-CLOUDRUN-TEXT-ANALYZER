locals {
  effective_project_id = var.create_project ? google_project.project[0].project_id : var.project_id
}

# Optional: create a project
resource "google_project" "project" {
  count            = var.create_project ? 1 : 0
  name             = var.project_id
  project_id       = var.project_id
  org_id           = var.org_id
  billing_account  = var.billing_account
  auto_create_network = false
}

# Enable required APIs
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com"
  ])
  project            = local.effective_project_id
  service            = each.key
  disable_on_destroy = false
}

# Artifact Registry (Docker)
resource "google_artifact_registry_repository" "repo" {
  provider      = google-beta
  location      = var.region
  repository_id = var.repo_id
  format        = "DOCKER"
  description   = "Container images for the text analyzer"
  project       = local.effective_project_id
  depends_on    = [google_project_service.services]
}

# Runtime service account (least privilege)
resource "google_service_account" "run_sa" {
  account_id   = "crun-text-analyzer"
  display_name = "Cloud Run runtime for ${var.service_name}"
  project      = local.effective_project_id
}

# Cloud Run v2 service (internal ingress + IAM-only)
resource "google_cloud_run_v2_service" "service" {
  name     = var.service_name
  location = var.region
  project  = local.effective_project_id

  # Internal LB only (not public). Alternative: INGRESS_TRAFFIC_INTERNAL_ONLY
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.run_sa.email

    containers {
      image = var.image
      ports { container_port = 8080 }
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
      startup_probe {
        http_get { path = "/healthz", port = 8080 }
        initial_delay_seconds = 1
        timeout_seconds       = 1
        period_seconds        = 5
        failure_threshold     = 3
      }
    }
  }

  # Ensure APIs are ready first
  depends_on = [google_project_service.services]
}

# Do NOT grant public invoker. Instead, optionally grant a specific principal.
# Example value for allowed_invoker:
#   serviceAccount:my-caller@<project>.iam.gserviceaccount.com
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  count   = var.allowed_invoker == null ? 0 : 1
  name    = google_cloud_run_v2_service.service.name
  project = local.effective_project_id
  location = var.region
  role    = "roles/run.invoker"
  member  = var.allowed_invoker
}

output "cloud_run_service_name" {
  value = google_cloud_run_v2_service.service.name
}

output "cloud_run_uri" {
  # Note: URI exists but will be reachable only via Internal HTTP(S) LB.
  value = google_cloud_run_v2_service.service.uri
}

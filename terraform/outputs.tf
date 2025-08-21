output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "The GCP region"
  value       = var.region
}

output "cloud_run_service_url" {
  description = "The URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.text_analyzer.uri
  sensitive   = false
}

output "cloud_run_service_name" {
  description = "The name of the Cloud Run service"
  value       = google_cloud_run_v2_service.text_analyzer.name
}

output "artifact_registry_repository" {
  description = "The Artifact Registry repository for container images"
  value       = google_artifact_registry_repository.app_repo.name
}

output "artifact_registry_url" {
  description = "The URL for pushing images to Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app_repo.repository_id}"
}

output "cloud_run_service_account_email" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloud_run_sa.email
}

output "cloud_build_service_account_email" {
  description = "Email of the Cloud Build service account"
  value       = google_service_account.cloud_build_sa.email
}

output "vpc_network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "vpc_connector_name" {
  description = "Name of the VPC connector"
  value       = google_vpc_access_connector.connector.name
}


# output "artifact_registry_repo" {
#   value = "${var.region}-docker.pkg.dev/${local.effective_project_id}/${google_artifact_registry_repository.repo.repository_id}"
# }

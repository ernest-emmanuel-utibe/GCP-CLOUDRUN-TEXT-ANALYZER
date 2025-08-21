output "artifact_registry_repo" {
  value = "${var.region}-docker.pkg.dev/${local.effective_project_id}/${google_artifact_registry_repository.repo.repository_id}"
}

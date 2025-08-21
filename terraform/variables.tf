variable "project_id" {
  description = "Existing GCP project ID (recommended). If creating a project, set also org_id and billing_account."
  type        = string
}

variable "create_project" {
  description = "Set true to create the project in Terraform (needs org_id and billing_account)."
  type        = bool
  default     = false
}

variable "org_id" {
  description = "Organization ID (only if create_project=true)."
  type        = string
  default     = null
}

variable "billing_account" {
  description = "Billing account ID (only if create_project=true)."
  type        = string
  default     = null
}

variable "region" {
  description = "Primary region for Artifact Registry and Cloud Run."
  type        = string
  default     = "europe-west1"
}

variable "repo_id" {
  description = "Artifact Registry repo name."
  type        = string
  default     = "text-analyzer"
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "text-analyzer-api"
}

variable "image" {
  description = "Container image reference (set by CI): REGION-docker.pkg.dev/PROJECT/REPO/IMAGE:TAG"
  type        = string
  default     = "REPLACE_IN_CI"
}

variable "allowed_invoker" {
  description = "Principal allowed to invoke the service (e.g., serviceAccount:my-caller@project.iam.gserviceaccount.com)."
  type        = string
  default     = null
}

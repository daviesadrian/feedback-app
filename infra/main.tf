terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
  default     = "cloud-portfolio-789"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

resource "google_project_service" "firestore" {
  project            = var.project_id
  service            = "firestore.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry" {
  project            = var.project_id
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "run" {
  project            = var.project_id
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "feedback_app" {
  project       = var.project_id
  location      = var.region
  repository_id = "feedback-app"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry]
}

resource "google_service_account" "feedback_app" {
  project      = var.project_id
  account_id   = "feedback-app-run"
  display_name = "Feedback app Cloud Run service account"
}

# Least privilege: only Firestore read/write, nothing else.
resource "google_project_iam_member" "feedback_app_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.feedback_app.email}"
}

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = "us-central1"
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.firestore]
}

resource "google_cloud_run_v2_service" "feedback_app" {
  project  = var.project_id
  name     = "feedback-app"
  location = var.region

  template {
    service_account = google_service_account.feedback_app.email

    containers {
      image = "us-central1-docker.pkg.dev/${var.project_id}/feedback-app/feedback-app:v1"

      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.project_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  depends_on = [google_project_service.run]
}

# Publicly reachable, like any customer-facing web form.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.feedback_app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

output "firestore_database" {
  value = google_firestore_database.default.name
}

output "cloud_run_url" {
  value = google_cloud_run_v2_service.feedback_app.uri
}

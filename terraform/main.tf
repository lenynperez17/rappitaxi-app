# OASIS TAXI - Terraform Infrastructure Configuration

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Local variables
locals {
  app_name = "oasis-taxi"
  environment = var.environment
  
  # Labels for all resources
  common_labels = {
    environment = var.environment
    project     = local.app_name
    managed_by  = "terraform"
  }
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "cloudfunctions.googleapis.com",
    "firestore.googleapis.com",
    "firebase.googleapis.com",
    "storage.googleapis.com",
    "cloudscheduler.googleapis.com",
    "pubsub.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "artifactregistry.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_dependent_services = false
  disable_on_destroy         = false
}

# Create a storage bucket for Cloud Functions source code
resource "google_storage_bucket" "functions_bucket" {
  name     = "${var.project_id}-functions-source"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# Create Firestore database
resource "google_firestore_database" "database" {
  provider    = google-beta
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.apis]
}

# Create Pub/Sub topics for scheduled functions
resource "google_pubsub_topic" "scheduled_functions" {
  for_each = toset([
    "cleanup-expired-rides",
    "driver-payouts",
    "daily-digest",
    "cleanup-notifications",
    "cleanup-tokens",
    "promotional-notifications",
    "reconcile-payments"
  ])

  name = each.value

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# Create Cloud Scheduler jobs
resource "google_cloud_scheduler_job" "scheduled_jobs" {
  for_each = {
    cleanup-expired-rides = {
      schedule    = "*/30 * * * *"  # Every 30 minutes
      description = "Cleanup expired ride requests"
      topic       = "cleanup-expired-rides"
    }
    driver-payouts = {
      schedule    = "0 9 * * 1"  # Every Monday at 9 AM
      description = "Process driver weekly payouts"
      topic       = "driver-payouts"
    }
    daily-digest = {
      schedule    = "0 19 * * *"  # Every day at 7 PM
      description = "Send daily digest notifications"
      topic       = "daily-digest"
    }
    cleanup-notifications = {
      schedule    = "0 3 * * 0"  # Every Sunday at 3 AM
      description = "Cleanup old read notifications"
      topic       = "cleanup-notifications"
    }
    cleanup-tokens = {
      schedule    = "0 4 * * 1"  # Every Monday at 4 AM
      description = "Cleanup invalid device tokens"
      topic       = "cleanup-tokens"
    }
    promotional-notifications = {
      schedule    = "0 20 * * 3,6"  # Wednesday and Saturday at 8 PM
      description = "Send promotional notifications"
      topic       = "promotional-notifications"
    }
    reconcile-payments = {
      schedule    = "0 4 * * *"  # Every day at 4 AM
      description = "Reconcile payment data"
      topic       = "reconcile-payments"
    }
  }

  name             = each.key
  description      = each.value.description
  schedule         = each.value.schedule
  time_zone        = "America/Argentina/Buenos_Aires"
  attempt_deadline = "320s"

  pubsub_target {
    topic_name = google_pubsub_topic.scheduled_functions[each.value.topic].id
    data       = base64encode("{\"trigger\":\"${each.key}\"}")
  }

  depends_on = [google_project_service.apis]
}

# Create Service Account for Cloud Functions
resource "google_service_account" "functions_sa" {
  account_id   = "${local.app_name}-functions"
  display_name = "OASIS TAXI Cloud Functions Service Account"
  description  = "Service account for OASIS TAXI Cloud Functions"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "functions_permissions" {
  for_each = toset([
    "roles/datastore.user",
    "roles/firebase.admin",
    "roles/storage.objectAdmin",
    "roles/pubsub.publisher",
    "roles/pubsub.subscriber",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/secretmanager.secretAccessor",
    "roles/cloudsql.client"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.functions_sa.email}"
}

# Create Secret Manager secrets for sensitive configuration
resource "google_secret_manager_secret" "secrets" {
  for_each = toset([
    "jwt-secret",
    "mercadopago-access-token",
    "mercadopago-public-key",
    "email-api-key",
    "sms-api-key",
    "firebase-private-key"
  ])

  secret_id = each.value

  replication {
    automatic = true
  }

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# Create Cloud Storage bucket for file uploads
resource "google_storage_bucket" "uploads_bucket" {
  name     = "${var.project_id}-uploads"
  location = var.region

  uniform_bucket_level_access = true

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# IAM policy for uploads bucket
resource "google_storage_bucket_iam_member" "uploads_bucket_access" {
  bucket = google_storage_bucket.uploads_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.functions_sa.email}"
}

# Create Cloud Build trigger for CI/CD
resource "google_cloudbuild_trigger" "deploy_trigger" {
  name        = "${local.app_name}-deploy"
  description = "Deploy OASIS TAXI Cloud Functions"

  github {
    owner = var.github_owner
    name  = var.github_repo
    push {
      branch = "^main$"
    }
  }

  build {
    step {
      name = "gcr.io/cloud-builders/npm"
      args = ["install"]
      dir  = "backend"
    }

    step {
      name = "gcr.io/cloud-builders/npm"
      args = ["run", "build"]
      dir  = "backend"
    }

    step {
      name = "gcr.io/cloud-builders/npm"
      args = ["run", "deploy"]
      dir  = "backend"
      env = [
        "GOOGLE_CLOUD_PROJECT=${var.project_id}",
        "FUNCTIONS_REGION=${var.region}"
      ]
    }

    options {
      logging = "CLOUD_LOGGING_ONLY"
    }
  }

  depends_on = [google_project_service.apis]
}

# Create monitoring alert policies
resource "google_monitoring_alert_policy" "function_errors" {
  display_name = "Cloud Function Error Rate"
  combiner     = "OR"

  conditions {
    display_name = "Cloud Function error rate"
    
    condition_threshold {
      filter         = "resource.type=\"cloud_function\""
      duration       = "300s"
      comparison     = "COMPARISON_GREATER_THAN"
      threshold_value = 0.1

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.function_name"]
      }
    }
  }

  notification_channels = []

  depends_on = [google_project_service.apis]
}

# Create Cloud Logging sinks
resource "google_logging_project_sink" "error_sink" {
  name        = "${local.app_name}-error-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"

  filter = "severity >= ERROR"

  unique_writer_identity = true
}

resource "google_storage_bucket" "logs_bucket" {
  name     = "${var.project_id}-logs"
  location = var.region

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# Grant the log sink writer access to the bucket
resource "google_storage_bucket_iam_member" "logs_bucket_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.error_sink.writer_identity
}
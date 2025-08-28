# OASIS TAXI - Terraform Outputs

output "project_id" {
  description = "The Google Cloud Project ID"
  value       = var.project_id
}

output "region" {
  description = "The Google Cloud region"
  value       = var.region
}

output "environment" {
  description = "The deployment environment"
  value       = var.environment
}

# Storage outputs
output "functions_bucket_name" {
  description = "Name of the Cloud Functions source bucket"
  value       = google_storage_bucket.functions_bucket.name
}

output "functions_bucket_url" {
  description = "URL of the Cloud Functions source bucket"
  value       = google_storage_bucket.functions_bucket.url
}

output "uploads_bucket_name" {
  description = "Name of the uploads bucket"
  value       = google_storage_bucket.uploads_bucket.name
}

output "uploads_bucket_url" {
  description = "URL of the uploads bucket"
  value       = google_storage_bucket.uploads_bucket.url
}

output "logs_bucket_name" {
  description = "Name of the logs bucket"
  value       = google_storage_bucket.logs_bucket.name
}

# Database outputs
output "firestore_database_name" {
  description = "Name of the Firestore database"
  value       = google_firestore_database.database.name
}

output "firestore_location" {
  description = "Location of the Firestore database"
  value       = google_firestore_database.database.location_id
}

# Service Account outputs
output "functions_service_account_email" {
  description = "Email of the Cloud Functions service account"
  value       = google_service_account.functions_sa.email
}

output "functions_service_account_id" {
  description = "ID of the Cloud Functions service account"
  value       = google_service_account.functions_sa.account_id
}

# Pub/Sub outputs
output "pubsub_topics" {
  description = "Map of Pub/Sub topic names"
  value = {
    for topic_name, topic in google_pubsub_topic.scheduled_functions :
    topic_name => topic.name
  }
}

# Scheduler outputs
output "scheduler_jobs" {
  description = "Map of Cloud Scheduler job names"
  value = {
    for job_name, job in google_cloud_scheduler_job.scheduled_jobs :
    job_name => job.name
  }
}

# Secret Manager outputs
output "secret_names" {
  description = "List of Secret Manager secret names"
  value       = [for secret in google_secret_manager_secret.secrets : secret.secret_id]
}

# Cloud Build outputs
output "cloudbuild_trigger_name" {
  description = "Name of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.deploy_trigger.name
}

output "cloudbuild_trigger_id" {
  description = "ID of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.deploy_trigger.trigger_id
}

# Monitoring outputs
output "alert_policy_names" {
  description = "List of monitoring alert policy names"
  value       = [google_monitoring_alert_policy.function_errors.display_name]
}

# API URLs (will be available after Cloud Functions deployment)
output "api_base_url" {
  description = "Base URL for the API (available after function deployment)"
  value       = "https://${var.region}-${var.project_id}.cloudfunctions.net/api"
}

output "function_urls" {
  description = "Map of individual function URLs (available after deployment)"
  value = {
    auth           = "https://${var.region}-${var.project_id}.cloudfunctions.net/auth"
    rides          = "https://${var.region}-${var.project_id}.cloudfunctions.net/rides"
    payments       = "https://${var.region}-${var.project_id}.cloudfunctions.net/payments"
    notifications  = "https://${var.region}-${var.project_id}.cloudfunctions.net/notifications"
  }
}

# Environment-specific configuration
output "environment_config" {
  description = "Environment configuration summary"
  value = {
    project_id           = var.project_id
    region              = var.region
    environment         = var.environment
    firestore_location  = var.firestore_location
    max_instances       = var.max_instances
    function_memory     = var.function_memory
    function_timeout    = var.function_timeout
    api_rate_limit      = var.api_rate_limit
    jwt_expiry_hours    = var.jwt_expiry_hours
    log_retention_days  = var.log_retention_days
    cache_ttl_seconds   = var.cache_ttl_seconds
  }
}

# Service configuration
output "service_config" {
  description = "Service configuration summary"
  value = {
    monitoring_enabled      = var.enable_monitoring
    logging_enabled        = var.enable_logging
    analytics_enabled      = var.enable_analytics
    cors_enabled           = var.enable_cors
    ssl_enabled            = var.enable_ssl
    compression_enabled    = var.enable_compression
    caching_enabled        = var.enable_caching
    rate_limiting_enabled  = var.enable_rate_limiting
    security_headers_enabled = var.enable_security_headers
    performance_monitoring_enabled = var.enable_performance_monitoring
  }
}

# Integration configuration
output "integration_config" {
  description = "Third-party integration configuration"
  value = {
    mercadopago_environment = var.mercadopago_environment
    email_provider         = var.email_provider
    sms_provider          = var.sms_provider
    fcm_enabled           = var.fcm_enabled
    performance_sample_rate = var.performance_sample_rate
  }
}

# Resource counts
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    storage_buckets     = 3
    pubsub_topics      = length(google_pubsub_topic.scheduled_functions)
    scheduler_jobs     = length(google_cloud_scheduler_job.scheduled_jobs)
    secrets           = length(google_secret_manager_secret.secrets)
    iam_bindings      = length(google_project_iam_member.functions_permissions)
    enabled_apis      = length(google_project_service.apis)
  }
}

# Deployment commands
output "deployment_commands" {
  description = "Commands for deploying the application"
  value = {
    terraform_init    = "terraform init"
    terraform_plan    = "terraform plan -var-file=terraform.tfvars"
    terraform_apply   = "terraform apply -var-file=terraform.tfvars"
    deploy_functions  = "cd ../backend && npm run deploy"
    deploy_frontend   = "cd ../app && flutter build web && firebase deploy --only hosting"
  }
}

# Security recommendations
output "security_checklist" {
  description = "Security configuration checklist"
  value = [
    "✓ Service account with minimal permissions created",
    "✓ Secret Manager configured for sensitive data",
    "✓ HTTPS enforced for all endpoints",
    "✓ CORS properly configured",
    "✓ Rate limiting enabled",
    "✓ Security headers enabled",
    "✓ Request logging enabled",
    "✓ Monitoring and alerting configured",
    "⚠ Remember to populate Secret Manager secrets before deployment",
    "⚠ Configure domain and SSL certificates for production",
    "⚠ Set up backup and disaster recovery procedures",
    "⚠ Review and update IAM permissions regularly"
  ]
}

# Post-deployment tasks
output "post_deployment_tasks" {
  description = "Tasks to complete after deployment"
  value = [
    "1. Populate Secret Manager secrets with actual values",
    "2. Configure Firebase Authentication providers",
    "3. Set up Firestore security rules and indexes",
    "4. Configure domain and SSL certificates",
    "5. Set up monitoring dashboards",
    "6. Configure backup schedules",
    "7. Test all API endpoints",
    "8. Deploy and test the Flutter application",
    "9. Configure push notification certificates",
    "10. Set up analytics and reporting"
  ]
}
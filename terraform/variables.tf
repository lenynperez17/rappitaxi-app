# OASIS TAXI - Terraform Variables

variable "project_id" {
  description = "The Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "The Google Cloud region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The Google Cloud zone for resources"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "firestore_location" {
  description = "Firestore database location"
  type        = string
  default     = "us-central"
  
  validation {
    condition = contains([
      "nam5", "us-central", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "eur3", "europe-west1", "europe-west2", "europe-west3", "europe-west6",
      "asia-south1", "asia-southeast1", "asia-northeast1", "asia-northeast2"
    ], var.firestore_location)
    error_message = "Invalid Firestore location. See https://cloud.google.com/firestore/docs/locations for valid locations."
  }
}

variable "github_owner" {
  description = "GitHub repository owner for CI/CD"
  type        = string
  default     = ""
}

variable "github_repo" {
  description = "GitHub repository name for CI/CD"
  type        = string
  default     = ""
}

variable "allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "max_instances" {
  description = "Maximum number of function instances"
  type        = number
  default     = 100
  
  validation {
    condition     = var.max_instances > 0 && var.max_instances <= 3000
    error_message = "Max instances must be between 1 and 3000."
  }
}

variable "function_memory" {
  description = "Memory allocation for Cloud Functions"
  type        = string
  default     = "512MB"
  
  validation {
    condition = contains([
      "128MB", "256MB", "512MB", "1GB", "2GB", "4GB", "8GB"
    ], var.function_memory)
    error_message = "Function memory must be one of: 128MB, 256MB, 512MB, 1GB, 2GB, 4GB, 8GB."
  }
}

variable "function_timeout" {
  description = "Timeout for Cloud Functions in seconds"
  type        = number
  default     = 60
  
  validation {
    condition     = var.function_timeout > 0 && var.function_timeout <= 540
    error_message = "Function timeout must be between 1 and 540 seconds."
  }
}

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Enable structured logging"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 90
  
  validation {
    condition     = var.log_retention_days > 0 && var.log_retention_days <= 3653
    error_message = "Log retention must be between 1 and 3653 days."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
  
  validation {
    condition     = var.backup_retention_days > 0 && var.backup_retention_days <= 365
    error_message = "Backup retention must be between 1 and 365 days."
  }
}

variable "notification_email" {
  description = "Email address for monitoring notifications"
  type        = string
  default     = ""
  
  validation {
    condition = var.notification_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.notification_email))
    error_message = "Notification email must be a valid email address or empty."
  }
}

variable "enable_ssl" {
  description = "Enable SSL/TLS for all endpoints"
  type        = bool
  default     = true
}

variable "api_rate_limit" {
  description = "API rate limit per minute per IP"
  type        = number
  default     = 100
  
  validation {
    condition     = var.api_rate_limit > 0 && var.api_rate_limit <= 10000
    error_message = "API rate limit must be between 1 and 10000 requests per minute."
  }
}

variable "jwt_expiry_hours" {
  description = "JWT token expiry time in hours"
  type        = number
  default     = 24
  
  validation {
    condition     = var.jwt_expiry_hours > 0 && var.jwt_expiry_hours <= 168
    error_message = "JWT expiry must be between 1 and 168 hours (1 week)."
  }
}

variable "enable_cors" {
  description = "Enable CORS for API endpoints"
  type        = bool
  default     = true
}

variable "enable_compression" {
  description = "Enable response compression"
  type        = bool
  default     = true
}

variable "enable_caching" {
  description = "Enable response caching"
  type        = bool
  default     = true
}

variable "cache_ttl_seconds" {
  description = "Cache TTL in seconds"
  type        = number
  default     = 300
  
  validation {
    condition     = var.cache_ttl_seconds >= 0 && var.cache_ttl_seconds <= 86400
    error_message = "Cache TTL must be between 0 and 86400 seconds (24 hours)."
  }
}

# MercadoPago configuration
variable "mercadopago_environment" {
  description = "MercadoPago environment (sandbox or production)"
  type        = string
  default     = "sandbox"
  
  validation {
    condition     = contains(["sandbox", "production"], var.mercadopago_environment)
    error_message = "MercadoPago environment must be either 'sandbox' or 'production'."
  }
}

# Email service configuration
variable "email_provider" {
  description = "Email service provider (sendgrid, ses, smtp)"
  type        = string
  default     = "sendgrid"
  
  validation {
    condition     = contains(["sendgrid", "ses", "smtp"], var.email_provider)
    error_message = "Email provider must be one of: sendgrid, ses, smtp."
  }
}

# SMS service configuration
variable "sms_provider" {
  description = "SMS service provider (twilio, aws-sns)"
  type        = string
  default     = "twilio"
  
  validation {
    condition     = contains(["twilio", "aws-sns"], var.sms_provider)
    error_message = "SMS provider must be one of: twilio, aws-sns."
  }
}

# Push notification configuration
variable "fcm_enabled" {
  description = "Enable Firebase Cloud Messaging"
  type        = bool
  default     = true
}

# Analytics configuration
variable "enable_analytics" {
  description = "Enable detailed analytics collection"
  type        = bool
  default     = true
}

variable "analytics_retention_days" {
  description = "Number of days to retain analytics data"
  type        = number
  default     = 365
  
  validation {
    condition     = var.analytics_retention_days > 0 && var.analytics_retention_days <= 2555
    error_message = "Analytics retention must be between 1 and 2555 days (7 years)."
  }
}

# Security configuration
variable "enable_security_headers" {
  description = "Enable security headers (HSTS, CSP, etc.)"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable API rate limiting"
  type        = bool
  default     = true
}

variable "enable_request_logging" {
  description = "Enable detailed request logging"
  type        = bool
  default     = true
}

# Performance configuration
variable "enable_performance_monitoring" {
  description = "Enable performance monitoring and tracing"
  type        = bool
  default     = true
}

variable "performance_sample_rate" {
  description = "Performance monitoring sample rate (0.0 to 1.0)"
  type        = number
  default     = 0.1
  
  validation {
    condition     = var.performance_sample_rate >= 0.0 && var.performance_sample_rate <= 1.0
    error_message = "Performance sample rate must be between 0.0 and 1.0."
  }
}
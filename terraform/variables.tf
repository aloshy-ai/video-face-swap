variable "project_id" {
  description = "The Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources"
  type        = string
  default     = "us-central1"
}

variable "container_image_url" {
  description = "The URL of the container image to deploy"
  type        = string
  default     = "us-central1-docker.pkg.dev/video-face-swap-459615/video-face-swap/api:latest"
}

variable "api_min_instances" {
  description = "Minimum number of instances for Cloud Run"
  type        = number
  default     = 1  # Keep at least one instance warm to avoid cold starts with model downloads
}

variable "api_max_instances" {
  description = "Maximum number of instances for Cloud Run"
  type        = number
  default     = 10
}

variable "api_concurrency" {
  description = "Concurrency per Cloud Run instance"
  type        = number
  default     = 5
}

variable "memory_limit" {
  description = "Memory limit for Cloud Run containers"
  type        = string
  default     = "4Gi"
}

variable "cpu_limit" {
  description = "CPU limit for Cloud Run containers"
  type        = string
  default     = "2"
}

variable "timeout_seconds" {
  description = "Maximum request duration in seconds"
  type        = number
  default     = 1200  # Increased to 20 minutes to accommodate first-request model downloads
}

variable "vpc_connector" {
  description = "VPC connector name for Cloud Run (optional)"
  type        = string
  default     = ""
}

variable "use_vpc_connector" {
  description = "Whether to use VPC connector"
  type        = bool
  default     = false
}

variable "enable_cloud_profiler" {
  description = "Whether to enable Google Cloud Profiler"
  type        = bool
  default     = false
}

variable "domain_name" {
  description = "Domain name for the service (optional)"
  type        = string
  default     = ""
}

variable "use_custom_domain" {
  description = "Whether to use custom domain"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Whether to enable enhanced monitoring"
  type        = bool
  default     = true
}

variable "labels" {
  description = "A map of labels to apply to resources"
  type        = map(string)
  default     = {
    environment = "prod"
    service     = "video-face-swap"
  }
}
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
  default     = 0
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
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
  
  # Uncomment the backend configuration when you're ready to use a shared state
  # backend "gcs" {
  #   bucket = "video-face-swap-459615-terraform-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Create Artifact Registry repository for storing container images
resource "google_artifact_registry_repository" "video_face_swap_repo" {
  location      = var.region
  repository_id = "video-face-swap"
  description   = "Docker repository for Video Face Swap API"
  format        = "DOCKER"
  
  labels = var.labels
}

# Enable vulnerability scanning for containers
resource "google_artifact_registry_repository_iam_member" "vulnerability_scanner" {
  provider   = google-beta
  project    = var.project_id
  location   = google_artifact_registry_repository.video_face_swap_repo.location
  repository = google_artifact_registry_repository.video_face_swap_repo.name
  role       = "roles/artifactregistry.vulnerabilityScannerUser"
  member     = "serviceAccount:service-${data.google_project.current.number}@container-analysis.iam.gserviceaccount.com"
  
  depends_on = [
    google_project_service.container_scanning_api
  ]
}

# Create Cloud Storage bucket for temporary files with uniformBucketLevelAccess
resource "google_storage_bucket" "temp_files" {
  name          = "${var.project_id}-vfs-temp"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
  
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
  
  labels = var.labels
}

# Service account for Cloud Run
resource "google_service_account" "video_face_swap_sa" {
  account_id   = "video-face-swap-sa"
  display_name = "Service Account for Video Face Swap API"
  description  = "Used by the Video Face Swap service to access GCP resources"
}

# Grant the service account access to the bucket
resource "google_storage_bucket_iam_member" "temp_bucket_access" {
  bucket = google_storage_bucket.temp_files.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.video_face_swap_sa.email}"
}

# Get the current project data
data "google_project" "current" {}

# Enable required APIs
resource "google_project_service" "cloud_run_api" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry_api" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container_scanning_api" {
  service            = "containerscanning.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "monitoring_api" {
  service            = "monitoring.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secretmanager_api" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# Cloud Run service for the API
resource "google_cloud_run_service" "video_face_swap_api" {
  name     = "video-face-swap-api"
  location = var.region
  
  # Wait for API enablement
  depends_on = [
    google_project_service.cloud_run_api,
    google_storage_bucket.temp_files,
    google_artifact_registry_repository.video_face_swap_repo
  ]

  template {
    spec {
      service_account_name = google_service_account.video_face_swap_sa.email
      
      containers {
        image = var.container_image_url
        
        resources {
          limits = {
            cpu    = var.cpu_limit
            memory = var.memory_limit
          }
        }
        
        env {
          name  = "TEMP_DIR"
          value = "/tmp"
        }
        
        env {
          name  = "STORAGE_BUCKET"
          value = google_storage_bucket.temp_files.name
        }
        
        env {
          name  = "PROJECT_ID"
          value = var.project_id
        }
        
        # Configure liveness and readiness probes with extended timeouts for model downloads
        startup_probe {
          http_get {
            path = "/health"
          }
          initial_delay_seconds = 30       # Increased to allow more time for model downloads
          timeout_seconds      = 10        # Increased for model initialization
          period_seconds       = 15        # Check less frequently during startup
          failure_threshold    = 6         # Allow more retry attempts
        }
        
        liveness_probe {
          http_get {
            path = "/health"
          }
          initial_delay_seconds = 60       # Increased delay after startup completes
          period_seconds       = 30
        }
      }
      
      container_concurrency = var.api_concurrency
      timeout_seconds       = var.timeout_seconds
    }
    
    metadata {
      annotations = merge(
        {
          "autoscaling.knative.dev/minScale" = tostring(var.api_min_instances)
          "autoscaling.knative.dev/maxScale" = tostring(var.api_max_instances)
          "run.googleapis.com/client-name"   = "terraform"
          "run.googleapis.com/startup-cpu-boost" = "true"  # Allocate more CPU during startup for faster model downloads
          "run.googleapis.com/cpu-throttling" = "false"  # Prevent CPU throttling
        },
        var.use_vpc_connector ? {
          "run.googleapis.com/vpc-access-connector" = var.vpc_connector
          "run.googleapis.com/vpc-access-egress"    = "all-traffic"
        } : {}
      )
      
      labels = var.labels
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
  
  # Configure custom domain if enabled
  dynamic "metadata" {
    for_each = var.use_custom_domain ? [1] : []
    content {
      annotations = {
        "run.googleapis.com/ingress" = "all"
      }
    }
  }
}

# Make Cloud Run service public
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.video_face_swap_api.name
  location = google_cloud_run_service.video_face_swap_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create a custom domain mapping if enabled
resource "google_cloud_run_domain_mapping" "custom_domain" {
  count    = var.use_custom_domain ? 1 : 0
  name     = var.domain_name
  location = var.region
  
  metadata {
    namespace = var.project_id
  }
  
  spec {
    route_name = google_cloud_run_service.video_face_swap_api.name
  }
}

# Create Cloud Monitoring dashboard with enhanced metrics
resource "google_monitoring_dashboard" "video_face_swap_dashboard" {
  count = var.enable_monitoring ? 1 : 0
  
  dashboard_json = <<EOF
{
  "displayName": "Video Face Swap API Dashboard",
  "gridLayout": {
    "widgets": [
      {
        "title": "Cloud Run Request Count",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            }
          ]
        }
      },
      {
        "title": "Cloud Run Response Latencies",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_99"
                  }
                }
              }
            }
          ]
        }
      },
      {
        "title": "Memory Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/container/memory/utilizations\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_95"
                  }
                }
              }
            }
          ]
        }
      },
      {
        "title": "CPU Utilization",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/container/cpu/utilizations\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_PERCENTILE_95"
                  }
                }
              }
            }
          ]
        }
      },
      {
        "title": "Error Rate",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\" metric.label.\"response_code_class\"=\"4xx\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            },
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\" metric.label.\"response_code_class\"=\"5xx\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_RATE"
                  }
                }
              }
            }
          ]
        }
      },
      {
        "title": "Instance Count",
        "xyChart": {
          "dataSets": [
            {
              "timeSeriesQuery": {
                "timeSeriesFilter": {
                  "filter": "metric.type=\"run.googleapis.com/container/instance_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\"",
                  "aggregation": {
                    "alignmentPeriod": "60s",
                    "perSeriesAligner": "ALIGN_MEAN"
                  }
                }
              }
            }
          ]
        }
      }
    ]
  }
}
EOF

  depends_on = [
    google_project_service.monitoring_api
  ]
}

# Create Cloud Monitoring alerts for error rates
resource "google_monitoring_alert_policy" "high_error_rate" {
  count = var.enable_monitoring ? 1 : 0
  
  display_name = "Video Face Swap API High Error Rate"
  combiner     = "OR"
  
  conditions {
    display_name = "High 5xx Error Rate"
    condition_threshold {
      filter     = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"video-face-swap-api\" metric.label.\"response_code_class\"=\"5xx\""
      duration   = "60s"
      comparison = "COMPARISON_GT"
      threshold_value = 5
      
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
      
      trigger {
        count = 1
      }
    }
  }
  
  alert_strategy {
    auto_close = "3600s"
  }
  
  documentation {
    content = "The Video Face Swap API is experiencing a high rate of 5xx errors."
  }
  
  depends_on = [
    google_project_service.monitoring_api
  ]
}

# Output the URL of the deployed service
output "service_url" {
  value = google_cloud_run_service.video_face_swap_api.status[0].url
}

# Output the Artifact Registry repository URL
output "artifact_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.video_face_swap_repo.repository_id}"
}

# Output the Cloud Storage bucket for temporary files
output "temp_storage_bucket" {
  value = google_storage_bucket.temp_files.name
}

# Output the URL for the custom domain if applicable
output "custom_domain_url" {
  value = var.use_custom_domain ? "https://${var.domain_name}" : "N/A"
}
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
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

# Create Artifact Registry repository for storing container images
resource "google_artifact_registry_repository" "video_face_swap_repo" {
  location      = var.region
  repository_id = "video-face-swap"
  description   = "Docker repository for Video Face Swap API"
  format        = "DOCKER"
}

# Create Cloud Storage bucket for temporary files
resource "google_storage_bucket" "temp_files" {
  name          = "${var.project_id}-vfs-temp"
  location      = var.region
  force_destroy = true
  
  lifecycle_rule {
    condition {
      age = 1
    }
    action {
      type = "Delete"
    }
  }
}

# Cloud Run service for the API
resource "google_cloud_run_service" "video_face_swap_api" {
  name     = "video-face-swap-api"
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image_url
        
        resources {
          limits = {
            cpu    = "2"
            memory = "4Gi"
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
      }
      
      container_concurrency = var.api_concurrency
      timeout_seconds       = 900  # 15 minutes
    }
    
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = tostring(var.api_min_instances)
        "autoscaling.knative.dev/maxScale" = tostring(var.api_max_instances)
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
  
  depends_on = [
    google_artifact_registry_repository.video_face_swap_repo,
    google_storage_bucket.temp_files
  ]
}

# Make Cloud Run service public
resource "google_cloud_run_service_iam_member" "public_access" {
  service  = google_cloud_run_service.video_face_swap_api.name
  location = google_cloud_run_service.video_face_swap_api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Create Cloud Monitoring dashboard
resource "google_monitoring_dashboard" "video_face_swap_dashboard" {
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
      }
    ]
  }
}
EOF
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
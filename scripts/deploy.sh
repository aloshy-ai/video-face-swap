#!/bin/bash
# deploy.sh - Script to deploy the Video Face Swap API infrastructure

set -e  # Exit on error

# Set default values
PROJECT_ID="video-face-swap-459615"
REGION="us-central1"
IMAGE_TAG="latest"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --project)
      PROJECT_ID="$2"
      shift 2
      ;;
    --region)
      REGION="$2"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --project PROJECT_ID   GCP project ID (default: $PROJECT_ID)"
      echo "  --region REGION        GCP region (default: $REGION)"
      echo "  --tag IMAGE_TAG        Container image tag (default: $IMAGE_TAG)"
      echo "  --help                 Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "===== Video Face Swap API Deployment ====="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Image Tag: $IMAGE_TAG"
echo "=========================================="

# Ensure necessary APIs are enabled
echo "Ensuring necessary APIs are enabled..."
gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  --project=$PROJECT_ID

# Create Artifact Registry repository if it doesn't exist
echo "Checking for Artifact Registry repository..."
if ! gcloud artifacts repositories describe video-face-swap \
     --location=$REGION --project=$PROJECT_ID &>/dev/null; then
  echo "Creating Artifact Registry repository..."
  gcloud artifacts repositories create video-face-swap \
    --repository-format=docker \
    --location=$REGION \
    --description="Docker repository for Video Face Swap API" \
    --project=$PROJECT_ID
fi

# Build and push Docker image
echo "Building Docker image..."
docker build -t $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$IMAGE_TAG .

echo "Pushing Docker image to Artifact Registry..."
docker push $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$IMAGE_TAG

# Initialize and apply Terraform
echo "Initializing Terraform..."
cd terraform
terraform init

echo "Applying Terraform configuration..."
terraform apply -auto-approve \
  -var "project_id=$PROJECT_ID" \
  -var "region=$REGION" \
  -var "container_image_url=$REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$IMAGE_TAG"

echo "Deployment complete! The API should now be available at the URL shown above."

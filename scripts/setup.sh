#!/bin/bash
# setup.sh - Initialize the Video Face Swap API project

set -e  # Exit on error

# Set default values
PROJECT_ID="video-face-swap-459615"
REGION="us-central1"

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
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --project PROJECT_ID   GCP project ID (default: $PROJECT_ID)"
      echo "  --region REGION        GCP region (default: $REGION)"
      echo "  --help                 Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "===== Video Face Swap API Setup ====="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "======================================"

# Ensure the user is logged in to gcloud
echo "Checking gcloud authentication..."
gcloud auth list --filter=status:ACTIVE --format="value(account)" || {
  echo "Please run 'gcloud auth login' to authenticate with Google Cloud."
  exit 1
}

# Verify the project exists and is accessible
echo "Verifying project..."
gcloud projects describe $PROJECT_ID &>/dev/null || {
  echo "Project $PROJECT_ID does not exist or you do not have access to it."
  exit 1
}

# Set the default project and region
echo "Setting default project and region..."
gcloud config set project $PROJECT_ID
gcloud config set run/region $REGION

# Enable necessary APIs
echo "Enabling necessary APIs..."
gcloud services enable \
  artifactregistry.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  storage.googleapis.com \
  iam.googleapis.com \
  monitoring.googleapis.com

# Create Artifact Registry repository
echo "Creating Artifact Registry repository..."
gcloud artifacts repositories create video-face-swap \
  --repository-format=docker \
  --location=$REGION \
  --description="Docker repository for Video Face Swap API" \
  --project=$PROJECT_ID || {
  echo "Repository already exists or there was an error creating it."
}

# Create a service account for Terraform (optional)
echo "Creating service account for Terraform..."
gcloud iam service-accounts create terraform-account \
  --display-name="Terraform Service Account" \
  --project=$PROJECT_ID || {
  echo "Service account already exists or there was an error creating it."
}

# Grant necessary permissions to the service account
echo "Granting permissions to service account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:terraform-account@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

# Create a Cloud Storage bucket for Terraform state (optional)
echo "Creating Cloud Storage bucket for Terraform state..."
gsutil mb -l $REGION gs://$PROJECT_ID-terraform-state || {
  echo "Bucket already exists or there was an error creating it."
}

# Enable versioning on the bucket
gsutil versioning set on gs://$PROJECT_ID-terraform-state

# Uncomment the backend configuration in the Terraform files
sed -i.bak 's/# backend "gcs" {/backend "gcs" {/' terraform/main.tf
sed -i.bak 's/#   bucket = "video-face-swap-459615-terraform-state"/  bucket = "'$PROJECT_ID'-terraform-state"/' terraform/main.tf
sed -i.bak 's/#   prefix = "terraform\/state"/  prefix = "terraform\/state"/' terraform/main.tf
sed -i.bak 's/# }/}/' terraform/main.tf

echo "Setup complete! You can now run the deploy script to deploy the application."
echo "Run: ./scripts/deploy.sh"

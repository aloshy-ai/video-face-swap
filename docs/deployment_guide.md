# Video Face Swap API - Deployment Guide

This guide provides step-by-step instructions for deploying the Video Face Swap API on Google Cloud Platform.

## Prerequisites

Before you begin, ensure you have the following:

1. **Google Cloud Platform Account** with billing enabled
2. **Project** created in GCP with required APIs enabled:
   - Cloud Run API
   - Artifact Registry API
   - Cloud Build API
   - Cloud Storage API
   - Cloud Monitoring API
   - Secret Manager API (optional)

3. **Local Development Environment** with:
   - [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and configured
   - [Docker](https://docs.docker.com/get-docker/) installed
   - [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli) v1.5+ installed

## Deployment Options

You can deploy the Video Face Swap API in several ways:

1. **Automated deployment** using the provided script
2. **Manual deployment** following the step-by-step instructions
3. **CI/CD pipeline** using Cloud Build

## Option 1: Automated Deployment

The simplest way to deploy is using the provided deployment script:

1. **Configure your environment**:
   ```bash
   # Authenticate with Google Cloud
   gcloud auth login
   
   # Set default project
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Run the deployment script**:
   ```bash
   cd scripts
   ./deploy.sh
   ```

3. **Follow the prompts** to complete the deployment.

## Option 2: Manual Deployment

### Step 1: Build the Docker Image

1. **Build the container image**:
   ```bash
   docker build -t video-face-swap-api:local .
   ```

2. **Test the container locally** (optional):
   ```bash
   docker run -p 8080:8080 video-face-swap-api:local
   ```

   Test the API at http://localhost:8080/health

### Step 2: Push to Artifact Registry

1. **Authenticate with Artifact Registry**:
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

2. **Create Artifact Registry repository** (if not exists):
   ```bash
   gcloud artifacts repositories create video-face-swap \
     --repository-format=docker \
     --location=us-central1 \
     --description="Video Face Swap API repository"
   ```

3. **Tag and push the image**:
   ```bash
   docker tag video-face-swap-api:local us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest
   docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest
   ```

### Step 3: Deploy with Terraform

1. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

2. **Apply the configuration**:
   ```bash
   terraform apply -var "project_id=YOUR_PROJECT_ID" \
     -var "region=us-central1" \
     -var "container_image_url=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest"
   ```

3. **Verify the deployment**:
   ```bash
   # Get the service URL
   terraform output service_url
   
   # Test the API
   curl $(terraform output -raw service_url)/health
   ```

## Option 3: CI/CD Pipeline with Cloud Build

To set up continuous deployment with Cloud Build:

1. **Connect your repository** to Cloud Build in the GCP Console

2. **Create a trigger** with the following configuration:
   - **Name**: video-face-swap-deploy
   - **Event**: Push to branch
   - **Source**: Your repository and branch
   - **Configuration**: cloudbuild.yaml
   - **Substitution variables**:
     - _REGION: us-central1 (or your preferred region)

3. **Push changes to your repository** to trigger the pipeline

## Testing the Deployment

### Basic Health Check

```bash
curl https://YOUR_SERVICE_URL/health
```

### Testing Face Swap

```bash
curl -X POST https://YOUR_SERVICE_URL/swap \
  -F "source=@path/to/source_face.jpg" \
  -F "target=@path/to/target_image.jpg" \
  -F "output_format=png" \
  -F "use_cloud_storage=true" \
  --output result.png
```

## Monitoring and Maintenance

### Viewing Logs

```bash
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=video-face-swap-api" --limit=10
```

### Monitoring Dashboard

1. Visit the [Cloud Monitoring Console](https://console.cloud.google.com/monitoring)
2. Navigate to Dashboards
3. Find the "Video Face Swap API Dashboard"

### Updating the Service

1. Build and push a new container image:
   ```bash
   docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:v2 .
   docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:v2
   ```

2. Update the Cloud Run service:
   ```bash
   cd terraform
   terraform apply -var "project_id=YOUR_PROJECT_ID" \
     -var "container_image_url=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:v2"
   ```

## Troubleshooting

### Common Issues

1. **403 Forbidden errors**: Check IAM permissions for the service account
2. **Image not found**: Ensure the image path in Artifact Registry is correct
3. **Cold start timeouts**: Adjust the minimum instances in terraform/variables.tf
4. **High latency**: Consider increasing CPU and memory limits

### Getting Help

If you encounter issues:

1. Check [Cloud Run logs](https://console.cloud.google.com/logs/query) for error messages
2. Review the [architecture documentation](./architecture_design.md) for design insights
3. Check the [GCP Status Dashboard](https://status.cloud.google.com/) for service disruptions

## Cleanup

To delete all deployed resources:

```bash
cd terraform
terraform destroy -var "project_id=YOUR_PROJECT_ID"
```

Or use the cleanup option in the deployment script:

```bash
cd scripts
./deploy.sh
# Select option 5 for cleanup
```

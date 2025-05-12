# Video Face Swap API - GCP Cloud Run Solution

This repository contains a production-ready implementation of a Video Face Swap API, built for Google Cloud Platform using Cloud Run, Artifact Registry, and Cloud Storage.

## Architecture

![Architecture Diagram](docs/architecture.png)

The application is built with the following GCP components:

- **Containerization**: Docker images stored in Artifact Registry
- **Compute**: Cloud Run for serverless container deployment
- **API**: Flask-based REST API for face swapping functionality
- **Storage**: Cloud Storage for temporary files and result storage
- **CI/CD**: Cloud Build for automated build, test, and deploy
- **IaC**: Terraform for infrastructure as code
- **Monitoring**: Cloud Monitoring dashboards and alerts
- **Logging**: Cloud Logging for centralized log management

## Features

- **Face Swapping**: High-quality face replacement in images and videos
- **Cloud Storage Integration**: Option to upload results to GCS
- **Horizontal Scaling**: Auto-scales based on demand
- **Health Monitoring**: Comprehensive health checks and benchmarking
- **Security**: Container vulnerability scanning and secure defaults

## Infrastructure as Code

All infrastructure is defined as code using Terraform in the `terraform/` directory:
- `main.tf`: Main Terraform configuration for all resources
- `variables.tf`: Variable definitions for customization
- `terraform.tfvars`: Variable values for your environment

## Getting Started

### Prerequisites

- Google Cloud account with billing enabled
- GCP project with required APIs enabled
- Local development:
  - Docker
  - Python 3.10+
  - Terraform 1.5+
  - gcloud CLI

### Local Development

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd video-face-swap
   ```

2. **Build the Docker image**:
   ```bash
   docker build -t video-face-swap-api:dev -f Dockerfile.optimized .
   ```

3. **Run the container locally**:
   ```bash
   docker run -p 8080:8080 video-face-swap-api:dev
   ```

4. **Test the API**:
   ```bash
   curl http://localhost:8080/health
   ```

### Deployment to GCP

#### Option 1: Manual Deployment

1. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Configure Docker to use Artifact Registry**:
   ```bash
   gcloud auth configure-docker us-central1-docker.pkg.dev
   ```

3. **Build and push the Docker image**:
   ```bash
   docker build -t us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest -f Dockerfile.optimized .
   docker push us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest
   ```

4. **Deploy with Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform apply -var "project_id=YOUR_PROJECT_ID" -var "container_image_url=us-central1-docker.pkg.dev/YOUR_PROJECT_ID/video-face-swap/api:latest"
   ```

#### Option 2: CI/CD Deployment

1. **Set up a trigger in Cloud Build** to watch your repository

2. **Configure the required substitution variables** in the Cloud Build trigger:
   - `_REGION`: Your preferred GCP region (e.g., us-central1)

3. **Push changes to your repository** to trigger the CI/CD pipeline

## API Usage

### Endpoints

- **GET /health**: Check API health
- **GET /benchmark**: Run performance benchmark
- **GET /model-info**: Get information about loaded models
- **POST /swap**: Perform face swapping

### Face Swap Request

```bash
curl -X POST http://YOUR_SERVICE_URL/swap \
  -F "source=@path/to/source_face.jpg" \
  -F "target=@path/to/target_image_or_video.jpg" \
  -F "output_format=mp4" \
  -F "keep_fps=true" \
  -F "many_faces=false" \
  -F "use_cloud_storage=true"
```

### Response

The API will return either:

1. A direct file download (if `use_cloud_storage=false`), or
2. A JSON response with a public Cloud Storage URL:
   ```json
   {
     "status": "success",
     "request_id": "12345-uuid",
     "url": "https://storage.googleapis.com/bucket/path/to/result.mp4",
     "processing_time": 12.34
   }
   ```

## Performance Optimization

This implementation includes several optimizations for GCP:

1. **Container Optimization**:
   - Minimal base image
   - Layer caching
   - Fixed dependency versions
   - Pre-loading models at build time

2. **Cloud Run Configuration**:
   - CPU/memory limits tuned for workload
   - Instance concurrency optimization
   - Startup/liveness probes
   - Minimum instances for reduced cold starts

3. **Storage Efficiency**:
   - Cloud Storage for temporary files
   - Lifecycle rules for automatic cleanup
   - Optimized file handling

## Monitoring and Observability

The deployment includes:

- **Custom Dashboard**: CPU, memory, request latency, and error rates
- **Alert Policies**: Notifications for high error rates or excessive latency
- **Structured Logging**: Request details, processing times, and error traces
- **Health Checks**: Comprehensive health and benchmark endpoints

## Security Features

- **Container Scanning**: Automatic vulnerability scanning
- **Non-root User**: Container runs as non-privileged user
- **Secret Management**: Support for Secret Manager integration
- **Minimal Permissions**: Service account with least privilege

## Cost Optimization

- **Serverless**: Pay only for what you use
- **Auto-scaling**: Scale to zero when not in use
- **Concurrency**: Process multiple requests per instance
- **Caching**: Pre-downloaded models reduce startup costs

## License

[Specify your license]

## Contributing

[Contribution guidelines]

## Project Status

[Current status, roadmap, etc.]

# Video Face Swap API Deployment Guide

This guide outlines the steps to deploy the Video Face Swap API to Google Cloud Platform (GCP) using Artifact Registry and Cloud Run. The solution provides an API that allows clients to swap faces in images and videos with just a single reference face image.

## Architecture Overview

The solution follows the comprehensive AI PaaS architecture:

- **API Management Layer**: Cloud API Gateway routes requests to our service
- **AI Service Layer**: Custom container with Roop/InsightFace runs on Cloud Run
- **Orchestration Layer**: Cloud Run Jobs for async processing of large videos
- **Data & Storage Layer**: Cloud Storage for temporary files and caching
- **Observability**: Cloud Monitoring and Logging for performance tracking

## Prerequisites

1. GCP Project with billing enabled
2. GCP APIs enabled:
   - Cloud Run API
   - Artifact Registry API
   - Cloud Build API
   - Container Registry API
   - Cloud Storage API
3. Required permissions:
   - Cloud Run Admin
   - Artifact Registry Writer
   - Cloud Build Editor
   - Storage Admin

## Deployment Steps

### 1. Set Up Artifact Registry

Create a Docker repository in Artifact Registry:

```bash
gcloud artifacts repositories create video-face-swap \
    --repository-format=docker \
    --location=us-central1 \
    --description="Docker repository for Video Face Swap API"
```

### 2. Configure Authentication

```bash
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### 3. Clone the Repository and Prepare Files

```bash
# Create a new directory
mkdir -p video-face-swap-api
cd video-face-swap-api

# Create the necessary files using the provided artifacts
# - Dockerfile
# - api.py
# - cloudbuild.yaml
# - test_client.py
```

### 4. Manual Build and Deploy (Option 1)

If you prefer to build and deploy manually:

```bash
# Build the Docker image
docker build -t us-central1-docker.pkg.dev/[PROJECT_ID]/video-face-swap/api:v1 .

# Push the image to Artifact Registry
docker push us-central1-docker.pkg.dev/[PROJECT_ID]/video-face-swap/api:v1

# Deploy to Cloud Run
gcloud run deploy video-face-swap-api \
    --image us-central1-docker.pkg.dev/[PROJECT_ID]/video-face-swap/api:v1 \
    --platform managed \
    --region us-central1 \
    --memory 4Gi \
    --cpu 2 \
    --min-instances 0 \
    --max-instances 10 \
    --concurrency 5 \
    --timeout 900s
```

### 5. Automated CI/CD Build (Option 2)

If you prefer to use Cloud Build for CI/CD:

```bash
# Submit a build to Cloud Build
gcloud builds submit --config=cloudbuild.yaml .
```

### 6. Create a Cloud Storage Bucket for Temp Files (Optional)

```bash
# Create a bucket for temporary files
gsutil mb -l us-central1 gs://[PROJECT_ID]-video-face-swap-temp

# Set lifecycle policy to delete files after 1 day
cat > lifecycle.json << EOL
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 1}
    }
  ]
}
EOL

gsutil lifecycle set lifecycle.json gs://[PROJECT_ID]-video-face-swap-temp
```

### 7. Configure API Gateway (Optional)

```bash
# Create an API Config
cat > api-config.yaml << EOL
swagger: '2.0'
info:
  title: Video Face Swap API
  description: API for swapping faces in images and videos
  version: 1.0.0
host: video-face-swap-api-gateway.endpoints.[PROJECT_ID].cloud.goog
schemes:
  - https
produces:
  - application/json
paths:
  /swap:
    post:
      operationId: faceSwap
      summary: Swap faces in images or videos
      x-google-backend:
        address: https://video-face-swap-api-[REGION]-run.app/swap
      consumes:
        - multipart/form-data
      parameters:
        - name: source
          in: formData
          description: Source image with a face
          required: true
          type: file
        - name: target
          in: formData
          description: Target image or video
          required: true
          type: file
        - name: output_format
          in: formData
          description: Output format for videos
          required: false
          type: string
          enum: [mp4, webm, mov, avi]
        - name: keep_frames
          in: formData
          description: Keep temporary frames
          required: false
          type: boolean
        - name: keep_fps
          in: formData
          description: Keep original FPS
          required: false
          type: boolean
        - name: many_faces
          in: formData
          description: Process multiple faces
          required: false
          type: boolean
        - name: skip_audio
          in: formData
          description: Skip audio in output
          required: false
          type: boolean
      responses:
        '200':
          description: Successful operation
        '400':
          description: Invalid input
        '500':
          description: Server error
  /health:
    get:
      operationId: healthCheck
      summary: Check API health
      x-google-backend:
        address: https://video-face-swap-api-[REGION]-run.app/health
      responses:
        '200':
          description: API is healthy
EOL

# Deploy the API Gateway
gcloud api-gateway api-configs create video-face-swap-config \
    --api=video-face-swap-api \
    --openapi-spec=api-config.yaml \
    --project=[PROJECT_ID]

gcloud api-gateway gateways create video-face-swap-gateway \
    --api=video-face-swap-api \
    --api-config=video-face-swap-config \
    --location=[REGION] \
    --project=[PROJECT_ID]
```

## Testing the API

Use the provided test client script to test the API:

```bash
python test_client.py \
    --api-url=https://video-face-swap-api-[REGION]-run.app \
    --source=source_face.jpg \
    --target=target_video.mp4 \
    --output=output_video.mp4 \
    --keep-fps
```

## API Documentation

### Endpoints

- **POST /swap**: Swap faces in images or videos
  - Request Body (multipart/form-data):
    - `source`: Image file with a face (JPEG, PNG)
    - `target`: Image or video file (JPEG, PNG, MP4, MOV, etc.)
    - `output_format`: Output format for videos (mp4, webm, mov, avi)
    - `keep_frames`: Keep temporary frames (boolean)
    - `keep_fps`: Keep original FPS (boolean)
    - `many_faces`: Process multiple faces (boolean)
    - `skip_audio`: Skip audio in output (boolean)
  - Response: The processed image or video file

- **GET /health**: Check API health
  - Response: `{"status": "healthy"}`

## Performance Considerations

- **Memory Usage**: The container uses up to 4GB of memory for processing
- **CPU Usage**: 2 CPUs allocated for faster processing
- **Processing Time**: 
  - Images: 2-5 seconds
  - Videos: 1-2 seconds per frame depending on resolution
- **Concurrency**: Set to 5 requests per instance
- **Scalability**: Auto-scales from 0 to 10 instances based on load

## Monitoring and Logging

- **Cloud Monitoring**: Set up dashboards for API metrics
- **Cloud Logging**: Review logs for debugging and performance analysis
- **Custom Metrics**: Track processing time, success rate, and error rate

## Security Considerations

- The API uses proper input validation
- Temporary files are securely handled and cleaned up
- Consider adding API authentication for production use
- The model includes safety checks to prevent misuse

## Cost Optimization

- Cloud Run scales to zero when not in use
- Temporary files are automatically deleted after processing
- Consider batch processing for large workloads
- Use regional resources to reduce network egress costs

## Troubleshooting

- **Container fails to start**: Check memory allocation and dependencies
- **Processing errors**: Verify input file formats and face detection
- **Performance issues**: Monitor CPU/memory usage and adjust resources
- **API gateway errors**: Check backend service configuration
# Video Face Swap API - Infrastructure as Code

This repository contains the code for a containerized Video Face Swap API, implemented with infrastructure as code principles for Google Cloud Platform.

## Architecture

The application is built with the following components:

- **Container**: The application is containerized using Docker
- **API**: Flask-based API for face swapping functionality
- **Storage**: Cloud Storage for temporary files
- **Deployment**: Cloud Run for scalable, serverless deployment
- **Registry**: Artifact Registry for container images
- **CI/CD**: Cloud Build for continuous integration and deployment
- **Organization Structure**: Deployed under the 'maas' folder in the GCP organization

## Infrastructure as Code

All infrastructure is defined as code using Terraform. The infrastructure code is located in the `terraform/` directory:

- `main.tf`: Main Terraform configuration for all resources
- `variables.tf`: Variable definitions
- `terraform.tfvars`: Variable values

This approach ensures that all infrastructure is versioned, reproducible, and can be deployed consistently across environments.

## CI/CD Pipeline

The CI/CD pipeline is defined in `cloudbuild.yaml` and performs the following steps:

1. Build the container image
2. Push the image to Artifact Registry
3. Initialize Terraform
4. Plan infrastructure changes
5. Apply infrastructure changes

## Deployment

To deploy the application manually:

1. Build the Docker image locally:
   ```bash
   docker build -t us-central1-docker.pkg.dev/video-face-swap-459615/video-face-swap/api:local .
   ```

2. Push the image to Artifact Registry:
   ```bash
   docker push us-central1-docker.pkg.dev/video-face-swap-459615/video-face-swap/api:local
   ```

3. Deploy the infrastructure with Terraform:
   ```bash
   cd terraform
   terraform init
   terraform apply -var "container_image_url=us-central1-docker.pkg.dev/video-face-swap-459615/video-face-swap/api:local"
   ```

For automatic deployments, push changes to the repository to trigger the Cloud Build pipeline.

## Repository Structure

```
video-face-swap/
├── Dockerfile              # Container definition
├── api.py                  # API code
├── cloudbuild.yaml         # CI/CD configuration
├── terraform/              # Infrastructure as code
│   ├── main.tf             # Main Terraform configuration
│   ├── variables.tf        # Variable definitions
│   └── terraform.tfvars    # Variable values
└── README.md               # This file
```

## Why This Approach

While Google Cloud provides Application Design Center (ADC) for visual infrastructure design, our implementation uses Terraform directly for several reasons:

1. **Reliability**: Direct Terraform usage provides maximum control over infrastructure
2. **Flexibility**: Easier customization and integration with existing systems
3. **Compatibility**: Works within our current folder structure under 'maas'
4. **Maturity**: Uses proven, widely-adopted infrastructure as code practices

This approach aligns with industry best practices for infrastructure as code while leveraging the existing Google Cloud organization structure.

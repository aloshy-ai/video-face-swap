# Video Face Swap API

A containerized API service that provides face swapping capabilities for images and videos using AI, built on Google Cloud Platform.

## Overview

This service provides an API endpoint that allows clients to swap faces in images and videos with just a single reference face image. It's designed to be scalable, efficient, and easy to use, leveraging Google Cloud's serverless infrastructure.

## Features

- Face swapping in images and videos with a single API call
- Supports various input and output formats
- Scalable architecture using Google Cloud Run
- Secure API management through API Gateway
- Efficient handling of large files

## Architecture

This service is built on the following components:

- **API Layer**: Flask-based REST API
- **AI Core**: InsightFace and Roop for face detection and swapping
- **Infrastructure**: Google Cloud Run, Container Registry, and API Gateway

## Repository Structure

```
video-face-swap/
├── Dockerfile               # Container definition
├── api.py                   # Flask API implementation
├── scripts/                 # Utility scripts
│   └── test_client.py       # Test script for the API
├── config/                  # Configuration files
│   ├── cloudbuild.yaml      # CI/CD configuration
│   ├── cloud-run-config.yaml # Cloud Run service config
│   └── api-gateway-config.yaml # API Gateway config
├── docs/                    # Documentation
│   └── deployment_guide.md  # Deployment instructions
└── models/                  # Directory for model files (Git LFS)
```

## Setup and Deployment

See [Deployment Guide](docs/deployment_guide.md) for detailed instructions.

## Using Git LFS for Model Files

This repository uses Git Large File Storage (LFS) to handle large model files. Make sure to install Git LFS before cloning:

```bash
# Install Git LFS
git lfs install

# Clone the repository
git clone <repository-url>

# Pull LFS files
git lfs pull
```

## API Documentation

### Endpoints

- **POST /swap**: Swap faces in images or videos
  - Takes a source image and target image/video
  - Returns the processed file

- **GET /health**: Health check endpoint
  - Returns status of the service

## License

This project is proprietary software.

## Acknowledgements

- [InsightFace](https://github.com/deepinsight/insightface) for face detection and analysis
- [Roop](https://github.com/s0md3v/roop) for face swapping capabilities

# Use a specific Python version for better reproducibility
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Add labels for better metadata in GCP
LABEL maintainer="aloshy-ai"
LABEL com.google.cloud.service="video-face-swap-api"

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TRANSFORMERS_CACHE=/app/.cache \
    DEBIAN_FRONTEND=noninteractive \
    PORT=8080

# Install system dependencies in a single layer to reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    build-essential \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Clone the video-face-swap repository with depth=1 to reduce download size
RUN git clone --depth=1 https://huggingface.co/spaces/ALSv/video-face-swap.git .

# Copy the API wrapper code and requirements
COPY api.py .
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Download required models on container build
# This pre-caches models so they don't need to be downloaded at runtime
RUN python -c "import insightface; from insightface.app import FaceAnalysis; app = FaceAnalysis(providers=['CPUExecutionProvider']); app.prepare(ctx_id=0, det_size=(640, 640))"

# Cloud Run requires your container to listen for requests on 0.0.0.0 
# on the port defined by the PORT environment variable
EXPOSE ${PORT}

# Set healthcheck to ensure container is healthy
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:${PORT}/health || exit 1

# Security: Run as non-root user
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Use exec form for CMD which is better for signal handling
CMD ["sh", "-c", "gunicorn --bind 0.0.0.0:${PORT} --workers 1 --threads 8 api:app"]
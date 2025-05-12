# Multi-stage build to reduce final image size

# Build stage
FROM python:3.10-slim AS builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive \
    GIT_LFS_SKIP_SMUDGE=1

# Set working directory
WORKDIR /build

# Install only essential build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    curl \
    gnupg2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Git LFS
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get update && \
    apt-get install -y git-lfs && \
    git lfs install

# Copy only requirements first to leverage Docker cache
COPY requirements.txt .

# Install Python dependencies with wheel building
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir wheel && \
    pip wheel --no-cache-dir --wheel-dir=/build/wheels -r requirements.txt

# Clone only necessary files from the repository
RUN git clone --depth=1 https://huggingface.co/spaces/ALSv/video-face-swap.git /tmp/repo && \
    cd /tmp/repo && \
    cp -r roop /build/ || true

# Final stage - minimal runtime image
FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TRANSFORMERS_CACHE=/app/.cache \
    PORT=8080

# Add GCP metadata and labels
LABEL maintainer="aloshy-ai" \
      com.google.cloud.service="video-face-swap-api"

# Install only runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-built wheels and install them
COPY --from=builder /build/wheels /wheels/
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/* && \
    rm -rf /wheels

# Copy application code
COPY --from=builder /build/roop/ /app/roop/
COPY api.py /app/
COPY scripts/startup-script.sh /app/startup-script.sh

# Make startup script executable
RUN chmod +x /app/startup-script.sh

# Create necessary directories
RUN mkdir -p /app/.models /app/.cache /app/.insightface

# Download required models
RUN python -c "import insightface; from insightface.app import FaceAnalysis; app = FaceAnalysis(providers=['CPUExecutionProvider']); app.prepare(ctx_id=0, det_size=(640, 640))"

# Create a non-root user
RUN adduser --disabled-password --gecos "" appuser && \
    chown -R appuser:appuser /app

# Set proper permissions
RUN chown -R appuser:appuser /app/.cache /app/.insightface /app/.models

# Switch to non-root user
USER appuser

# Expose the port
EXPOSE ${PORT}

# Set healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:${PORT}/health || exit 1

# Command to run the application
ENTRYPOINT ["/app/startup-script.sh"]
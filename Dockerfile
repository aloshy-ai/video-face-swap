# Enhanced multi-stage build with optimized Docker cache utilization

# Build stage
FROM python:3.10-slim AS builder

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    DEBIAN_FRONTEND=noninteractive \
    GIT_LFS_SKIP_SMUDGE=1 \
    PIP_NO_CACHE_DIR=1

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

# Install Git LFS with verification
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get update && \
    apt-get install -y git-lfs && \
    git lfs install && \
    git lfs --version

# Copy requirements first to leverage Docker cache
COPY requirements.txt .

# Build wheels in a dedicated layer for better caching
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir wheel && \
    pip wheel --no-cache-dir --wheel-dir=/build/wheels -r requirements.txt

# Clone only necessary files using Git LFS skip smudge
RUN git clone --depth=1 https://huggingface.co/spaces/ALSv/video-face-swap.git /tmp/repo && \
    cd /tmp/repo && \
    # Selectively pull only the model files we need
    git lfs pull --include="models/inswapper_128.onnx" && \
    git lfs pull --include="models/detection_Resnet50_Final.pth" && \
    cp -r roop /build/ || true && \
    mkdir -p /build/models && \
    cp -r /tmp/repo/models/* /build/models/ 2>/dev/null || true

# Final stage - minimal runtime image
FROM python:3.10-slim AS runtime

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    TRANSFORMERS_CACHE=/app/.cache \
    PORT=8080 \
    OMP_NUM_THREADS=1 \
    PYTHONHASHSEED=0 \
    TF_CPP_MIN_LOG_LEVEL=2

# Add GCP metadata and labels
LABEL maintainer="aloshy-ai" \
      com.google.cloud.service="video-face-swap-api" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.version="${VERSION}"

# Install runtime dependencies in a single layer to reduce image size
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

# Copy application code and models
COPY --from=builder /build/roop/ /app/roop/
COPY --from=builder /build/models/ /app/models/
COPY api.py /app/
COPY scripts/startup-script.sh /app/startup-script.sh

# Make startup script executable
RUN chmod +x /app/startup-script.sh

# Create necessary directories with proper permissions
RUN mkdir -p /app/.models /app/.cache /app/.insightface && \
    ln -sf /app/models/* /app/.models/ 2>/dev/null || true

# Initialize insightface with prebuilt model paths
RUN python -c "import os; os.environ['PYTHONPATH'] = '/app'; import insightface; from insightface.app import FaceAnalysis; app = FaceAnalysis(providers=['CPUExecutionProvider']); app.prepare(ctx_id=0, det_size=(640, 640))"

# Add metadata file for model version tracking
RUN echo "Build date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')" > /app/model_metadata.txt && \
    echo "Model version: 1.0.0" >> /app/model_metadata.txt

# Create a non-root user
RUN adduser --disabled-password --gecos "" appuser && \
    chown -R appuser:appuser /app

# Set proper permissions
RUN chown -R appuser:appuser /app/.cache /app/.insightface /app/.models /app/models

# Switch to non-root user
USER appuser

# Expose the port
EXPOSE ${PORT}

# Set healthcheck
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:${PORT}/health || exit 1

# Command to run the application
ENTRYPOINT ["/app/startup-script.sh"]
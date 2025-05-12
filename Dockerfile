FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    git \
    libgl1-mesa-glx \
    libglib2.0-0 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Clone the video-face-swap repository
RUN git clone https://huggingface.co/spaces/ALSv/video-face-swap.git .

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV TRANSFORMERS_CACHE=/app/.cache

# Install Python dependencies
# Note: Insightface is a key dependency for face swapping
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    insightface==0.7.3 \
    numpy>=1.24.3 \
    opencv-python>=4.7.0.72 \
    onnx>=1.14.0 \
    onnxruntime>=1.15.0 \
    psutil>=5.9.0 \
    customtkinter>=5.1.3 \
    Pillow>=9.5.0 \
    tqdm>=4.65.0 \
    torch>=2.0.0 \
    torchvision>=0.15.1 \
    flask>=2.3.2 \
    pydantic>=2.0.0 \
    python-multipart>=0.0.6 \
    gunicorn>=21.2.0

# Copy the API wrapper code
COPY api.py .

# Download required models on container build
# This pre-caches models so they don't need to be downloaded at runtime
RUN python -c "import insightface; from insightface.app import FaceAnalysis; app = FaceAnalysis(providers=['CPUExecutionProvider']); app.prepare(ctx_id=0, det_size=(640, 640))"

# Expose port for the API
EXPOSE 8080

# Run the API server using gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "1", "--threads", "8", "api:app"]
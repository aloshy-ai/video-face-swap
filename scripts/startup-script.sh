#!/bin/bash
# startup-script.sh - Prewarms the container by downloading models in parallel
# This script is executed when the container starts

# Function to download model files in the background
download_models() {
  # Execute a Python script to download models in the background
  python -c '
import threading
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("model-prewarmer")

# Function to download face swapper model
def download_face_swapper():
    try:
        logger.info("Starting face swapper model download...")
        import insightface
        from insightface.app import FaceAnalysis
        
        # Download face detection model
        logger.info("Downloading face detection model...")
        app = FaceAnalysis(providers=["CPUExecutionProvider"])
        app.prepare(ctx_id=0, det_size=(640, 640))
        logger.info("Face detection model downloaded successfully")
    except Exception as e:
        logger.error(f"Error downloading face swapper model: {e}")

# Start download in a separate thread
download_thread = threading.Thread(target=download_face_swapper)
download_thread.daemon = True
download_thread.start()

logger.info("Model download started in background")
' &
}

# Start model downloads in the background
download_models

# Continue with normal container startup
echo "Container prewarm script executed, container starting normally"
exec "$@"

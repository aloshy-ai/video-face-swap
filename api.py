import os
import uuid
import shutil
import tempfile
from typing import Optional
from flask import Flask, request, jsonify, send_file
import cv2
import numpy as np
from pydantic import BaseModel
import logging
import time
import google.cloud.logging
from google.cloud import storage
import json
import traceback

# Import roop modules
import roop.globals
from roop.processors.frame.face_swapper import get_face_swapper
from roop.face_analyser import get_face_analyser, get_one_face
from roop.utilities import is_image, is_video, resolve_relative_path

# Configure logging with Google Cloud Logging
try:
    # Setup Google Cloud Logging
    client = google.cloud.logging.Client()
    client.setup_logging()
    logging.info("Google Cloud Logging enabled")
except Exception as e:
    # Fall back to standard logging if GCP logging fails
    logging.basicConfig(level=logging.INFO, 
                        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    logging.warning(f"Failed to setup GCP logging, using standard logging: {str(e)}")

logger = logging.getLogger(__name__)

# Initialize Flask app with enhanced configuration
app = Flask(__name__)

# Initialize Cloud Storage client if bucket name is provided
storage_client = None
bucket = None
STORAGE_BUCKET = os.environ.get('STORAGE_BUCKET')

if STORAGE_BUCKET:
    try:
        storage_client = storage.Client()
        bucket = storage_client.bucket(STORAGE_BUCKET)
        logger.info(f"Connected to Cloud Storage bucket: {STORAGE_BUCKET}")
    except Exception as e:
        logger.error(f"Failed to connect to Cloud Storage bucket: {str(e)}")

# Initialize the face swapper
face_swapper = None
face_analyser = None

# Input validation model with enhanced options
class SwapRequest(BaseModel):
    output_format: str = "mp4"
    keep_frames: bool = False
    keep_fps: bool = True
    many_faces: bool = False
    skip_audio: bool = False
    use_cloud_storage: bool = True  # Whether to use GCS for temp files

def initialize_models():
    """Initialize the face swapper and analyzer models"""
    global face_swapper, face_analyser
    
    start_time = time.time()
    
    if face_swapper is None:
        logger.info("Initializing face swapper...")
        face_swapper = get_face_swapper()
    
    if face_analyser is None:
        logger.info("Initializing face analyzer...")
        face_analyser = get_face_analyser()
    
    logger.info(f"Models initialized in {time.time() - start_time:.2f} seconds")

def process_image(source_path, target_path, output_path):
    """Process a single image for face swapping"""
    
    # Read source and target images
    source_image = cv2.imread(source_path)
    target_image = cv2.imread(target_path)
    
    if source_image is None or target_image is None:
        raise ValueError("Failed to read source or target image")
    
    # Get source face
    source_face = get_one_face(source_image)
    if source_face is None:
        raise ValueError("No face detected in source image")
    
    # Process frame with face swapper
    result = face_swapper.process_frame(source_face, target_image)
    
    # Save result
    cv2.imwrite(output_path, result)
    return output_path

def process_video(source_path, target_path, output_path, params):
    """Process a video for face swapping - delegates to roop's core functionality"""
    
    # Set global parameters
    roop.globals.source_path = source_path
    roop.globals.target_path = target_path
    roop.globals.output_path = output_path
    roop.globals.keep_fps = params.keep_fps
    roop.globals.keep_frames = params.keep_frames
    roop.globals.skip_audio = params.skip_audio
    roop.globals.many_faces = params.many_faces
    
    # Import necessary modules only when needed for video processing
    from roop.core import suggest_execution_providers, limit_resources, pre_check, process_video
    from roop.processors.frame.core import get_frame_processors_modules
    
    # Set frame processors
    roop.globals.frame_processors = ["face_swapper"]
    
    # Limit memory resources
    limit_resources()
    
    # Perform pre-check
    pre_check()
    
    # Process the video
    return process_video()

def upload_to_gcs(local_path, gcs_object_name=None):
    """Upload a file to GCS bucket and return public URL"""
    if not storage_client or not bucket:
        return None
    
    if gcs_object_name is None:
        gcs_object_name = f"temp/{str(uuid.uuid4())}/{os.path.basename(local_path)}"
    
    blob = bucket.blob(gcs_object_name)
    blob.upload_from_filename(local_path)
    
    # Make the blob publicly accessible
    blob.make_public()
    
    return blob.public_url

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint with enhanced diagnostics"""
    status = {
        "status": "healthy",
        "timestamp": time.time(),
        "version": os.environ.get('VERSION', 'development'),
        "models_loaded": face_swapper is not None and face_analyser is not None,
        "cloud_storage": STORAGE_BUCKET is not None
    }
    
    return jsonify(status)

@app.route('/swap', methods=['POST'])
def face_swap():
    """Face swap endpoint that accepts source face and target image/video"""
    request_id = str(uuid.uuid4())
    start_time = time.time()
    
    # Create temp directory for this request
    temp_dir = tempfile.mkdtemp()
    
    # Track metrics for Cloud Monitoring
    metrics = {
        "request_id": request_id,
        "start_time": start_time,
        "temp_dir": temp_dir,
        "source_file_size": 0,
        "target_file_size": 0,
        "output_file_size": 0,
        "processing_time": 0,
        "status": "started"
    }
    
    try:
        # Initialize models if needed
        initialize_models()
        
        # Get files from request
        if 'source' not in request.files or 'target' not in request.files:
            metrics["status"] = "error_missing_files"
            return jsonify({"error": "Both source and target files are required", "request_id": request_id}), 400
        
        source_file = request.files['source']
        target_file = request.files['target']
        
        metrics["source_filename"] = source_file.filename
        metrics["target_filename"] = target_file.filename
        
        # Get parameters
        try:
            params_dict = request.form.to_dict()
            params = SwapRequest(**params_dict)
        except Exception as e:
            metrics["status"] = "error_invalid_params"
            return jsonify({"error": f"Invalid parameters: {str(e)}", "request_id": request_id}), 400
        
        # Save files to temp directory
        source_path = os.path.join(temp_dir, f"source_{request_id}{os.path.splitext(source_file.filename)[1]}")
        target_path = os.path.join(temp_dir, f"target_{request_id}{os.path.splitext(target_file.filename)[1]}")
        
        source_file.save(source_path)
        target_file.save(target_path)
        
        metrics["source_file_size"] = os.path.getsize(source_path)
        metrics["target_file_size"] = os.path.getsize(target_path)
        
        # Check file types
        if not is_image(source_path):
            metrics["status"] = "error_invalid_source"
            return jsonify({"error": "Source file must be an image", "request_id": request_id}), 400
        
        if not (is_image(target_path) or is_video(target_path)):
            metrics["status"] = "error_invalid_target"
            return jsonify({"error": "Target file must be an image or video", "request_id": request_id}), 400
        
        # Generate output path
        is_target_image = is_image(target_path)
        metrics["target_type"] = "image" if is_target_image else "video"
        
        if is_target_image:
            output_path = os.path.join(temp_dir, f"output_{request_id}.png")
            result_path = process_image(source_path, target_path, output_path)
            content_type = "image/png"
        else:
            # For video
            output_ext = params.output_format.lower()
            if output_ext not in ["mp4", "webm", "mov", "avi"]:
                output_ext = "mp4"  # Default to mp4 if not specified
                
            output_path = os.path.join(temp_dir, f"output_{request_id}.{output_ext}")
            process_video(source_path, target_path, output_path, params)
            
            if output_ext == "mp4":
                content_type = "video/mp4"
            elif output_ext == "webm":
                content_type = "video/webm"
            elif output_ext == "mov":
                content_type = "video/quicktime"
            else:
                content_type = "video/x-msvideo"
            
            result_path = output_path
        
        # Check if output file exists
        if not os.path.exists(result_path):
            metrics["status"] = "error_processing_failed"
            return jsonify({"error": "Failed to generate output file", "request_id": request_id}), 500
        
        metrics["output_file_size"] = os.path.getsize(result_path)
        
        # Use Cloud Storage if enabled and available
        gcs_url = None
        if params.use_cloud_storage and bucket:
            try:
                # Upload to Cloud Storage
                gcs_url = upload_to_gcs(result_path)
                if gcs_url:
                    metrics["storage_type"] = "cloud_storage"
                    metrics["status"] = "success"
                    # Log processing time
                    processing_time = time.time() - start_time
                    metrics["processing_time"] = processing_time
                    logger.info(f"Processing completed in {processing_time:.2f} seconds. Result uploaded to {gcs_url}")
                    
                    # Return the URL instead of the file
                    return jsonify({
                        "status": "success",
                        "request_id": request_id,
                        "url": gcs_url,
                        "processing_time": processing_time
                    })
            except Exception as e:
                logger.warning(f"Cloud Storage upload failed, falling back to direct file return: {str(e)}")
                # Continue with direct file return
        
        # Log processing time
        processing_time = time.time() - start_time
        metrics["processing_time"] = processing_time
        metrics["storage_type"] = "direct"
        metrics["status"] = "success"
        logger.info(f"Processing completed in {processing_time:.2f} seconds")
        
        # Return the processed file directly
        return send_file(
            result_path,
            mimetype=content_type,
            as_attachment=True,
            download_name=os.path.basename(result_path)
        )
    
    except Exception as e:
        error_details = {
            "error": str(e),
            "request_id": request_id,
            "traceback": traceback.format_exc()
        }
        
        metrics["status"] = "error_exception"
        metrics["error"] = str(e)
        metrics["processing_time"] = time.time() - start_time
        
        logger.error(f"Error during processing: {json.dumps(error_details)}")
        return jsonify({"error": str(e), "request_id": request_id}), 500
    
    finally:
        # Log metrics for monitoring
        logger.info(f"Request metrics: {json.dumps(metrics)}")
        
        # Clean up temp files (delayed to ensure file is sent)
        def cleanup():
            try:
                if os.path.exists(temp_dir):
                    shutil.rmtree(temp_dir)
                    logger.debug(f"Cleaned up temporary directory {temp_dir}")
            except Exception as e:
                logger.error(f"Error cleaning up: {str(e)}")
        
        # Schedule cleanup after response is sent
        import threading
        t = threading.Timer(60, cleanup)
        t.daemon = True
        t.start()

# Add benchmark endpoint for performance testing
@app.route('/benchmark', methods=['GET'])
def benchmark():
    """Run a quick benchmark to test face swapping performance"""
    try:
        # Initialize models if needed
        initialize_models()
        
        # Create a simple test image (100x100 blank image with a simple face-like shape)
        source_image = np.ones((100, 100, 3), dtype=np.uint8) * 255
        # Draw a simple circle for face
        cv2.circle(source_image, (50, 50), 30, (0, 0, 0), 2)
        # Draw eyes
        cv2.circle(source_image, (40, 40), 5, (0, 0, 0), -1)
        cv2.circle(source_image, (60, 40), 5, (0, 0, 0), -1)
        # Draw mouth
        cv2.rectangle(source_image, (40, 60), (60, 70), (0, 0, 0), 2)
        
        # Create a target image (same as source for simplicity)
        target_image = source_image.copy()
        
        # Start benchmark
        start_time = time.time()
        
        # Create temp dir
        temp_dir = tempfile.mkdtemp()
        
        try:
            # Save images
            source_path = os.path.join(temp_dir, "source_test.png")
            target_path = os.path.join(temp_dir, "target_test.png")
            output_path = os.path.join(temp_dir, "output_test.png")
            
            cv2.imwrite(source_path, source_image)
            cv2.imwrite(target_path, target_image)
            
            # Get source face (this might fail with our simple test image, but that's ok for benchmarking)
            # We'll just time the face detection
            try:
                source_face = get_one_face(source_image)
                if source_face is None:
                    logger.warning("Benchmark: No face detected in test image")
            except:
                logger.warning("Benchmark: Face detection failed on test image")
            
            end_time = time.time()
            
            # Return benchmark results
            return jsonify({
                "status": "success",
                "benchmark_time": end_time - start_time,
                "memory_usage_mb": int(os.popen('ps -p %d -o rss | tail -1' % os.getpid()).read()) / 1024,
                "models_loaded": face_swapper is not None and face_analyser is not None
            })
        finally:
            # Clean up
            if os.path.exists(temp_dir):
                shutil.rmtree(temp_dir)
    
    except Exception as e:
        logger.error(f"Benchmark error: {str(e)}")
        return jsonify({"error": str(e)}), 500

# Add model info endpoint
@app.route('/model-info', methods=['GET'])
def model_info():
    """Return information about loaded models"""
    try:
        # Initialize models if needed
        initialize_models()
        
        info = {
            "models_loaded": face_swapper is not None and face_analyser is not None,
            "face_swapper": str(type(face_swapper).__name__) if face_swapper else None,
            "face_analyser": str(type(face_analyser).__name__) if face_analyser else None,
            "memory_usage_mb": int(os.popen('ps -p %d -o rss | tail -1' % os.getpid()).read()) / 1024,
            "environment": os.environ.get("ENVIRONMENT", "development"),
            "container_id": os.environ.get("HOSTNAME", "unknown")
        }
        
        return jsonify(info)
    
    except Exception as e:
        logger.error(f"Model info error: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(debug=False, host='0.0.0.0', port=port)

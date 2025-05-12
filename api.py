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

# Import roop modules
import roop.globals
from roop.processors.frame.face_swapper import get_face_swapper
from roop.face_analyser import get_face_analyser, get_one_face
from roop.utilities import is_image, is_video, resolve_relative_path

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Initialize the face swapper
face_swapper = None
face_analyser = None

# Input validation model
class SwapRequest(BaseModel):
    output_format: str = "mp4"
    keep_frames: bool = False
    keep_fps: bool = True
    many_faces: bool = False
    skip_audio: bool = False

def initialize_models():
    """Initialize the face swapper and analyzer models"""
    global face_swapper, face_analyser
    
    if face_swapper is None:
        logger.info("Initializing face swapper...")
        face_swapper = get_face_swapper()
    
    if face_analyser is None:
        logger.info("Initializing face analyzer...")
        face_analyser = get_face_analyser()

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

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "healthy"})

@app.route('/swap', methods=['POST'])
def face_swap():
    """Face swap endpoint that accepts source face and target image/video"""
    start_time = time.time()
    
    # Create temp directory for this request
    temp_dir = tempfile.mkdtemp()
    
    try:
        # Initialize models if needed
        initialize_models()
        
        # Get files from request
        if 'source' not in request.files or 'target' not in request.files:
            return jsonify({"error": "Both source and target files are required"}), 400
        
        source_file = request.files['source']
        target_file = request.files['target']
        
        # Get parameters
        try:
            params_dict = request.form.to_dict()
            params = SwapRequest(**params_dict)
        except Exception as e:
            return jsonify({"error": f"Invalid parameters: {str(e)}"}), 400
        
        # Save files to temp directory
        source_path = os.path.join(temp_dir, f"source_{uuid.uuid4()}{os.path.splitext(source_file.filename)[1]}")
        target_path = os.path.join(temp_dir, f"target_{uuid.uuid4()}{os.path.splitext(target_file.filename)[1]}")
        
        source_file.save(source_path)
        target_file.save(target_path)
        
        # Check file types
        if not is_image(source_path):
            return jsonify({"error": "Source file must be an image"}), 400
        
        if not (is_image(target_path) or is_video(target_path)):
            return jsonify({"error": "Target file must be an image or video"}), 400
        
        # Generate output path
        if is_image(target_path):
            output_path = os.path.join(temp_dir, f"output_{uuid.uuid4()}.png")
            result_path = process_image(source_path, target_path, output_path)
            content_type = "image/png"
        else:
            # For video
            output_ext = params.output_format.lower()
            if output_ext not in ["mp4", "webm", "mov", "avi"]:
                output_ext = "mp4"  # Default to mp4 if not specified
                
            output_path = os.path.join(temp_dir, f"output_{uuid.uuid4()}.{output_ext}")
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
            return jsonify({"error": "Failed to generate output file"}), 500
        
        # Log processing time
        processing_time = time.time() - start_time
        logger.info(f"Processing completed in {processing_time:.2f} seconds")
        
        # Return the processed file
        return send_file(
            result_path,
            mimetype=content_type,
            as_attachment=True,
            download_name=os.path.basename(result_path)
        )
    
    except Exception as e:
        logger.error(f"Error during processing: {str(e)}", exc_info=True)
        return jsonify({"error": str(e)}), 500
    
    finally:
        # Clean up temp files (delayed to ensure file is sent)
        def cleanup():
            try:
                if os.path.exists(temp_dir):
                    shutil.rmtree(temp_dir)
            except Exception as e:
                logger.error(f"Error cleaning up: {str(e)}")
        
        # Schedule cleanup after response is sent
        # In production with gunicorn, this should use a better cleanup strategy
        import threading
        t = threading.Timer(60, cleanup)
        t.daemon = True
        t.start()

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))
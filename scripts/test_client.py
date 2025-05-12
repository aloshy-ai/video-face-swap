#!/usr/bin/env python3
"""
Test client for the video-face-swap API service.
This script sends a source image and target image/video to the API for face swapping.
"""

import argparse
import os
import requests
import time

def main():
    parser = argparse.ArgumentParser(description='Test the face swap API')
    parser.add_argument('--api-url', required=True, help='URL of the API endpoint')
    parser.add_argument('--source', required=True, help='Path to source image (face to use)')
    parser.add_argument('--target', required=True, help='Path to target image or video')
    parser.add_argument('--output', required=True, help='Path to save the output file')
    parser.add_argument('--keep-frames', action='store_true', help='Keep temporary frames')
    parser.add_argument('--keep-fps', action='store_true', help='Keep original FPS')
    parser.add_argument('--many-faces', action='store_true', help='Process multiple faces')
    parser.add_argument('--skip-audio', action='store_true', help='Skip audio in output')
    parser.add_argument('--output-format', default='mp4', help='Output format (for videos): mp4, webm, mov, avi')
    
    args = parser.parse_args()
    
    # Check if files exist
    if not os.path.exists(args.source):
        print(f"Source file {args.source} does not exist")
        return
    
    if not os.path.exists(args.target):
        print(f"Target file {args.target} does not exist")
        return
    
    # Prepare files to send
    with open(args.source, 'rb') as source_file, open(args.target, 'rb') as target_file:
        print("Sending files to API...")
        start_time = time.time()
        
        # Prepare the form data
        files = {
            'source': (os.path.basename(args.source), source_file, 'image/jpeg'),
            'target': (os.path.basename(args.target), target_file, 'application/octet-stream')
        }
        
        # Prepare parameters
        params = {
            'output_format': args.output_format,
            'keep_frames': str(args.keep_frames).lower(),
            'keep_fps': str(args.keep_fps).lower(),
            'many_faces': str(args.many_faces).lower(),
            'skip_audio': str(args.skip_audio).lower()
        }
        
        # Send request to API
        response = requests.post(
            f"{args.api_url}/swap",
            files=files,
            data=params,
            stream=True  # Important for large files
        )
        
        # Check if the request was successful
        if response.status_code == 200:
            # Get the content type
            content_type = response.headers.get('Content-Type', '')
            
            # Save the response to the output file
            with open(args.output, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192): 
                    f.write(chunk)
            
            elapsed_time = time.time() - start_time
            print(f"Success! Output saved to {args.output}")
            print(f"Processing took {elapsed_time:.2f} seconds")
        else:
            print(f"Error: {response.status_code}")
            print(response.text)

if __name__ == "__main__":
    main()
#!/usr/bin/env python3
"""
Video Face Swap API - Test Client
A simple client to test the Video Face Swap API functionality.
"""

import argparse
import os
import requests
import json
import time
from urllib.parse import urljoin
import sys

def print_colored(text, color):
    """Print colored text in the terminal."""
    colors = {
        'green': '\033[92m',
        'yellow': '\033[93m',
        'red': '\033[91m',
        'blue': '\033[94m',
        'end': '\033[0m'
    }
    print(f"{colors.get(color, '')}{text}{colors['end']}")

def test_health(base_url):
    """Test the health endpoint of the API."""
    url = urljoin(base_url, '/health')
    print_colored(f"Testing health endpoint: {url}", "blue")
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        print_colored("Health check successful!", "green")
        print(json.dumps(response.json(), indent=2))
        return True
    except requests.exceptions.RequestException as e:
        print_colored(f"Health check failed: {str(e)}", "red")
        return False

def test_benchmark(base_url):
    """Test the benchmark endpoint of the API."""
    url = urljoin(base_url, '/benchmark')
    print_colored(f"Testing benchmark endpoint: {url}", "blue")
    
    try:
        start_time = time.time()
        response = requests.get(url, timeout=30)
        response.raise_for_status()
        elapsed = time.time() - start_time
        
        print_colored(f"Benchmark completed in {elapsed:.2f} seconds!", "green")
        print(json.dumps(response.json(), indent=2))
        return True
    except requests.exceptions.RequestException as e:
        print_colored(f"Benchmark failed: {str(e)}", "red")
        return False

def test_model_info(base_url):
    """Test the model-info endpoint of the API."""
    url = urljoin(base_url, '/model-info')
    print_colored(f"Testing model-info endpoint: {url}", "blue")
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        
        print_colored("Model info retrieved successfully!", "green")
        print(json.dumps(response.json(), indent=2))
        return True
    except requests.exceptions.RequestException as e:
        print_colored(f"Model info failed: {str(e)}", "red")
        return False

def test_face_swap(base_url, source_path, target_path, output_path, use_cloud_storage=True):
    """Test the face swap endpoint of the API."""
    url = urljoin(base_url, '/swap')
    print_colored(f"Testing face swap endpoint: {url}", "blue")
    
    # Validate input files
    if not os.path.exists(source_path):
        print_colored(f"Source file not found: {source_path}", "red")
        return False
    
    if not os.path.exists(target_path):
        print_colored(f"Target file not found: {target_path}", "red")
        return False
    
    # Determine output format from target file extension
    target_ext = os.path.splitext(target_path)[1].lower()
    if target_ext in ['.mp4', '.avi', '.mov', '.webm']:
        is_video = True
        output_format = target_ext[1:]  # Remove the dot
    else:
        is_video = False
        output_format = "png"
    
    print_colored(f"Source: {source_path}", "blue")
    print_colored(f"Target: {target_path} ({'video' if is_video else 'image'})", "blue")
    print_colored(f"Output: {output_path}", "blue")
    
    # Prepare files and parameters
    files = {
        'source': open(source_path, 'rb'),
        'target': open(target_path, 'rb')
    }
    
    data = {
        'output_format': output_format,
        'keep_fps': 'true',
        'many_faces': 'false',
        'use_cloud_storage': str(use_cloud_storage).lower()
    }
    
    try:
        print_colored("Sending request... (this may take a while for videos)", "yellow")
        start_time = time.time()
        response = requests.post(url, files=files, data=data, timeout=300)  # 5-minute timeout
        elapsed = time.time() - start_time
        
        # Close file handles
        for f in files.values():
            f.close()
        
        # Handle the response
        if response.status_code == 200:
            # Check if we got JSON (cloud storage URL) or binary data
            content_type = response.headers.get('Content-Type', '')
            
            if 'application/json' in content_type:
                result = response.json()
                print_colored(f"Face swap completed in {elapsed:.2f} seconds!", "green")
                print(json.dumps(result, indent=2))
                
                # If we have a URL, we can download the file
                if 'url' in result:
                    print_colored(f"Downloading result from: {result['url']}", "blue")
                    download_response = requests.get(result['url'], timeout=60)
                    with open(output_path, 'wb') as f:
                        f.write(download_response.content)
                    print_colored(f"Downloaded and saved to: {output_path}", "green")
            else:
                # Binary response, save directly
                with open(output_path, 'wb') as f:
                    f.write(response.content)
                print_colored(f"Face swap completed in {elapsed:.2f} seconds and saved to: {output_path}", "green")
            
            return True
        else:
            print_colored(f"Face swap failed with status code: {response.status_code}", "red")
            print(response.text)
            return False
            
    except requests.exceptions.RequestException as e:
        print_colored(f"Face swap request failed: {str(e)}", "red")
        # Close file handles if still open
        for f in files.values():
            try:
                f.close()
            except:
                pass
        return False

def main():
    parser = argparse.ArgumentParser(description='Test client for the Video Face Swap API')
    parser.add_argument('--url', required=True, help='Base URL of the API (e.g., http://localhost:8080)')
    parser.add_argument('--command', choices=['health', 'benchmark', 'model-info', 'swap', 'all'], 
                        default='health', help='Command to run')
    parser.add_argument('--source', help='Source image path (for face swap)')
    parser.add_argument('--target', help='Target image or video path (for face swap)')
    parser.add_argument('--output', help='Output file path (for face swap)')
    parser.add_argument('--use-cloud-storage', action='store_true', 
                        help='Use cloud storage for results (default: False)')
    
    args = parser.parse_args()
    
    # Normalize the base URL to ensure it doesn't end with a slash
    base_url = args.url.rstrip('/')
    
    if args.command == 'health' or args.command == 'all':
        test_health(base_url)
        
    if args.command == 'benchmark' or args.command == 'all':
        test_benchmark(base_url)
        
    if args.command == 'model-info' or args.command == 'all':
        test_model_info(base_url)
        
    if args.command == 'swap' or args.command == 'all':
        if args.command == 'all' and (not args.source or not args.target or not args.output):
            print_colored("Skipping face swap test because source, target, or output not provided", "yellow")
        elif not args.source or not args.target or not args.output:
            print_colored("Error: For face swap, you must provide --source, --target, and --output", "red")
            sys.exit(1)
        else:
            test_face_swap(base_url, args.source, args.target, args.output, args.use_cloud_storage)

if __name__ == "__main__":
    main()

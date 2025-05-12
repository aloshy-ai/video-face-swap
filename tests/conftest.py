"""
conftest.py - Shared test fixtures and configurations for pytest
"""
import os
import sys
import pytest
import tempfile
import numpy as np
import cv2
from io import BytesIO

# Add the project root to the Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

# Mock environment variables for testing
os.environ['TEST_ENV'] = 'True'
os.environ['STORAGE_BUCKET'] = 'test-bucket'

@pytest.fixture
def app():
    """Create a test instance of the Flask app"""
    from api import app as flask_app
    # Configure the app for testing
    flask_app.config['TESTING'] = True
    return flask_app

@pytest.fixture
def client(app):
    """Create a test client for the Flask app"""
    return app.test_client()

@pytest.fixture
def mock_storage(monkeypatch):
    """Mock the Google Cloud Storage client"""
    class MockBlob:
        def __init__(self, name, bucket):
            self.name = name
            self.bucket = bucket
            self.public_url = f"https://storage.googleapis.com/{bucket.name}/{name}"
        
        def upload_from_filename(self, filename):
            # Mock upload functionality
            pass
        
        def make_public(self):
            # Mock make public functionality
            pass
    
    class MockBucket:
        def __init__(self, name):
            self.name = name
        
        def blob(self, name):
            return MockBlob(name, self)
    
    class MockStorageClient:
        def __init__(self):
            pass
        
        def bucket(self, name):
            return MockBucket(name)
    
    # Patch the storage client
    monkeypatch.setattr('google.cloud.storage.Client', MockStorageClient)
    
    return MockStorageClient()

@pytest.fixture
def test_images():
    """Create test images for face swapping tests"""
    # Create a simple test image (100x100 blank image with a face-like shape)
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
    
    # Save test images to temporary files
    source_file = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    target_file = tempfile.NamedTemporaryFile(suffix='.png', delete=False)
    
    cv2.imwrite(source_file.name, source_image)
    cv2.imwrite(target_file.name, target_image)
    
    # Read files as binary data
    with open(source_file.name, 'rb') as f:
        source_data = f.read()
        
    with open(target_file.name, 'rb') as f:
        target_data = f.read()
    
    # Return a dictionary with all the test data
    result = {
        'source_file': source_file.name,
        'target_file': target_file.name,
        'source_data': source_data,
        'target_data': target_data,
        'source_image': source_image,
        'target_image': target_image
    }
    
    yield result
    
    # Clean up temporary files
    try:
        os.unlink(source_file.name)
        os.unlink(target_file.name)
    except:
        pass

@pytest.fixture
def mock_face_swapper(monkeypatch):
    """Mock the face swapper functionality"""
    class MockFaceSwapper:
        def process_frame(self, source_face, target_image):
            # Return the target image with minimal modification to show it worked
            # In a real test, you might want to add a visual marker to show the swap happened
            result = target_image.copy()
            # Add a small marker to indicate processing happened
            cv2.rectangle(result, (10, 10), (20, 20), (0, 255, 0), -1)
            return result
    
    class MockFaceAnalyser:
        def get(self, image, threshold=0.5):
            # Return a mock face
            return [{'bbox': (10, 10, 50, 50)}]
    
    # Patch the face swapper and analyser
    import api
    monkeypatch.setattr(api, 'face_swapper', MockFaceSwapper())
    monkeypatch.setattr(api, 'face_analyser', MockFaceAnalyser())
    
    # Also patch the get_one_face function
    def mock_get_one_face(image):
        # Return a mock face embedding
        return {'embedding': np.random.rand(512)}
    
    from roop.face_analyser import get_one_face
    monkeypatch.setattr('roop.face_analyser.get_one_face', mock_get_one_face)
    
    return MockFaceSwapper()

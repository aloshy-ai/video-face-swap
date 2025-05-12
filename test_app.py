import unittest
import json
import os
import tempfile
from io import BytesIO
import numpy as np
import cv2
from api import app

# NOTICE: This file is deprecated.
# Please use the new test structure in the 'tests' directory instead.
# Run tests with: pytest tests/
# See pytest.ini for configuration options.

class TestVideoFaceSwapAPI(unittest.TestCase):
    """Test suite for the Video Face Swap API"""
    
    def setUp(self):
        """Set up test client and test images"""
        self.app = app.test_client()
        self.app.testing = True
        
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
        _, self.source_file = tempfile.mkstemp(suffix='.png')
        _, self.target_file = tempfile.mkstemp(suffix='.png')
        
        cv2.imwrite(self.source_file, source_image)
        cv2.imwrite(self.target_file, target_image)
        
        # Read files as binary data
        with open(self.source_file, 'rb') as f:
            self.source_data = f.read()
            
        with open(self.target_file, 'rb') as f:
            self.target_data = f.read()
    
    def tearDown(self):
        """Clean up test files"""
        try:
            os.unlink(self.source_file)
            os.unlink(self.target_file)
        except:
            pass
    
    def test_health_endpoint(self):
        """Test health check endpoint"""
        response = self.app.get('/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn(data['status'], ['healthy', 'initializing'])
    
    def test_missing_files(self):
        """Test API response when files are missing"""
        response = self.app.post('/swap')
        self.assertEqual(response.status_code, 400)
        data = json.loads(response.data)
        self.assertIn('error', data)
    
    def test_benchmark_endpoint(self):
        """Test benchmark endpoint"""
        response = self.app.get('/benchmark')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('benchmark_time', data)
    
    def test_model_info_endpoint(self):
        """Test model info endpoint"""
        response = self.app.get('/model-info')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertIn('models_loaded', data)

    @unittest.skip("Skip actual face swap test in CI environment")
    def test_face_swap_image(self):
        """Test face swap with images (skipped in CI environment)"""
        data = {
            'source': (BytesIO(self.source_data), 'source.png'),
            'target': (BytesIO(self.target_data), 'target.png'),
        }
        
        response = self.app.post('/swap', data=data, content_type='multipart/form-data')
        
        # Note: This test will likely fail in a CI environment without proper models
        # It's mainly here for local testing
        self.assertEqual(response.status_code, 200)

if __name__ == '__main__':
    unittest.main()

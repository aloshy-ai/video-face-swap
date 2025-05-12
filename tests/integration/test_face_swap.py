"""
Integration tests for the face swap functionality
"""
import json
import os
import pytest
from io import BytesIO
import numpy as np
import cv2

@pytest.mark.integration
@pytest.mark.api
def test_face_swap_image_with_mock(client, test_images, mock_face_swapper, mock_storage):
    """Test face swap with images using mocked face swapper"""
    data = {
        'source': (BytesIO(test_images['source_data']), 'source.png'),
        'target': (BytesIO(test_images['target_data']), 'target.png'),
        'use_cloud_storage': 'true'
    }
    
    response = client.post('/swap', data=data, content_type='multipart/form-data')
    
    assert response.status_code == 200
    json_data = json.loads(response.data)
    assert 'status' in json_data
    assert json_data['status'] == 'success'
    assert 'url' in json_data
    assert json_data['url'].startswith('https://storage.googleapis.com/')
    assert 'request_id' in json_data
    assert 'processing_time' in json_data

@pytest.mark.integration
@pytest.mark.api
def test_face_swap_direct_return(client, test_images, mock_face_swapper):
    """Test face swap with direct file return (not using cloud storage)"""
    data = {
        'source': (BytesIO(test_images['source_data']), 'source.png'),
        'target': (BytesIO(test_images['target_data']), 'target.png'),
        'use_cloud_storage': 'false'
    }
    
    response = client.post('/swap', data=data, content_type='multipart/form-data')
    
    assert response.status_code == 200
    # Check that we got an image back, not JSON
    assert response.content_type.startswith('image/')
    # Verify the response contains image data by trying to decode it
    img_array = np.frombuffer(response.data, np.uint8)
    img = cv2.imdecode(img_array, cv2.IMREAD_COLOR)
    assert img is not None
    assert img.shape[0] > 0 and img.shape[1] > 0  # Image has dimensions

@pytest.mark.integration
@pytest.mark.api
@pytest.mark.parametrize('output_format', ['png', 'jpg'])
def test_face_swap_image_formats(client, test_images, mock_face_swapper, output_format):
    """Test face swap with different output image formats"""
    data = {
        'source': (BytesIO(test_images['source_data']), 'source.png'),
        'target': (BytesIO(test_images['target_data']), 'target.png'),
        'use_cloud_storage': 'false',
        'output_format': output_format
    }
    
    response = client.post('/swap', data=data, content_type='multipart/form-data')
    
    assert response.status_code == 200
    # Check that we got an image back with the right format
    if output_format == 'png':
        assert response.content_type == 'image/png'
    elif output_format == 'jpg':
        assert response.content_type in ['image/jpeg', 'image/jpg']

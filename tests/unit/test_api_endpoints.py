"""
Test file for API endpoints (unit tests)
"""
import json
import os
import pytest
from io import BytesIO
import time

@pytest.mark.unit
@pytest.mark.api
def test_health_endpoint(client):
    """Test the health endpoint returns the correct response"""
    response = client.get('/health')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert data['status'] in ['healthy', 'initializing']
    assert 'timestamp' in data
    assert 'models_loaded' in data
    assert 'cloud_storage' in data

@pytest.mark.unit
@pytest.mark.api
def test_missing_files(client):
    """Test API response when files are missing"""
    response = client.post('/swap')
    assert response.status_code == 400
    data = json.loads(response.data)
    assert 'error' in data
    assert 'request_id' in data

@pytest.mark.unit
@pytest.mark.api
def test_benchmark_endpoint(client):
    """Test benchmark endpoint returns the correct data structure"""
    response = client.get('/benchmark')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'benchmark_time' in data
    assert 'status' in data
    assert data['status'] == 'success'
    assert 'memory_usage_mb' in data

@pytest.mark.unit
@pytest.mark.api
def test_model_info_endpoint(client):
    """Test model info endpoint returns the correct data structure"""
    response = client.get('/model-info')
    assert response.status_code == 200
    data = json.loads(response.data)
    assert 'models_loaded' in data
    assert 'memory_usage_mb' in data
    assert 'environment' in data

@pytest.mark.unit
@pytest.mark.api
def test_invalid_file_types(client, test_images):
    """Test API response with invalid file types"""
    # Create a text file instead of an image
    text_data = b'This is not an image file'
    
    # Test with invalid source
    data = {
        'source': (BytesIO(text_data), 'source.txt'),
        'target': (BytesIO(test_images['target_data']), 'target.png'),
    }
    
    response = client.post('/swap', data=data, content_type='multipart/form-data')
    assert response.status_code == 400
    json_data = json.loads(response.data)
    assert 'error' in json_data
    assert 'Source file must be an image' in json_data['error']
    
    # Test with invalid target
    data = {
        'source': (BytesIO(test_images['source_data']), 'source.png'),
        'target': (BytesIO(text_data), 'target.txt'),
    }
    
    response = client.post('/swap', data=data, content_type='multipart/form-data')
    assert response.status_code == 400
    json_data = json.loads(response.data)
    assert 'error' in json_data
    assert 'Target file must be an image or video' in json_data['error']

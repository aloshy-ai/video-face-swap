"""
Performance tests for the API
"""
import json
import time
import pytest
import statistics
from io import BytesIO

@pytest.mark.performance
@pytest.mark.api
def test_health_endpoint_performance(client):
    """Test the performance of the health endpoint"""
    # Number of requests to make
    num_requests = 10
    response_times = []
    
    for _ in range(num_requests):
        start_time = time.time()
        response = client.get('/health')
        end_time = time.time()
        
        assert response.status_code == 200
        response_times.append(end_time - start_time)
    
    # Calculate statistics
    avg_time = statistics.mean(response_times)
    p95_time = sorted(response_times)[int(num_requests * 0.95) - 1]
    max_time = max(response_times)
    
    print(f"Health Endpoint Performance:")
    print(f"  Average response time: {avg_time:.4f} seconds")
    print(f"  95th percentile: {p95_time:.4f} seconds")
    print(f"  Max response time: {max_time:.4f} seconds")
    
    # Assert reasonable performance (adjust thresholds as needed)
    assert avg_time < 0.1, f"Average response time too high: {avg_time:.4f}s"
    assert p95_time < 0.2, f"95th percentile response time too high: {p95_time:.4f}s"

@pytest.mark.performance
@pytest.mark.api
def test_benchmark_endpoint_performance(client):
    """Test the performance of the benchmark endpoint itself"""
    start_time = time.time()
    response = client.get('/benchmark')
    end_time = time.time()
    
    assert response.status_code == 200
    data = json.loads(response.data)
    
    # Verify the benchmark data
    assert 'benchmark_time' in data
    assert 'status' in data
    assert data['status'] == 'success'
    
    # Calculate the overhead of the benchmark endpoint itself
    endpoint_time = end_time - start_time
    benchmark_time = data['benchmark_time']
    
    print(f"Benchmark Endpoint Performance:")
    print(f"  Total endpoint time: {endpoint_time:.4f} seconds")
    print(f"  Reported benchmark time: {benchmark_time:.4f} seconds")
    print(f"  Overhead: {endpoint_time - benchmark_time:.4f} seconds")
    
    # Assert that the endpoint overhead is reasonable
    assert endpoint_time < benchmark_time * 1.5, f"Benchmark endpoint overhead too high"

@pytest.mark.performance
@pytest.mark.api
@pytest.mark.slow
def test_face_swap_performance(client, test_images, mock_face_swapper):
    """Test the performance of the face swap endpoint with mock swapper"""
    # Performance test configuration
    num_requests = 3
    
    # Create test data
    data = {
        'source': (BytesIO(test_images['source_data']), 'source.png'),
        'target': (BytesIO(test_images['target_data']), 'target.png'),
        'use_cloud_storage': 'false'
    }
    
    response_times = []
    
    for i in range(num_requests):
        start_time = time.time()
        response = client.post('/swap', data=data, content_type='multipart/form-data')
        end_time = time.time()
        
        assert response.status_code == 200
        response_times.append(end_time - start_time)
        
        # Small delay between requests
        time.sleep(0.1)
    
    # Calculate statistics
    avg_time = statistics.mean(response_times)
    min_time = min(response_times)
    max_time = max(response_times)
    
    print(f"Face Swap Performance (with mocked swapper):")
    print(f"  Average response time: {avg_time:.4f} seconds")
    print(f"  Min response time: {min_time:.4f} seconds")
    print(f"  Max response time: {max_time:.4f} seconds")
    
    # With mocked swapper, response should be fast
    assert avg_time < 1.0, f"Average face swap time too high: {avg_time:.4f}s"

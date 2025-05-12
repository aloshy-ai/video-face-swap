#!/bin/bash
# Video Face Swap API - Mock Test
# This script mocks the API responses for quick testing

set -e

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Video Face Swap API - Mock Test            ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Create a temporary directory to serve as our API
TEMP_DIR=$(mktemp -d)
echo -e "${GREEN}Created mock API at: ${NC}$TEMP_DIR"

# Create mock health endpoint
cat > "$TEMP_DIR/health.json" << EOF
{
  "status": "healthy",
  "timestamp": $(date +%s),
  "version": "0.1.0",
  "models_loaded": true,
  "cloud_storage": true
}
EOF

# Create mock benchmark endpoint
cat > "$TEMP_DIR/benchmark.json" << EOF
{
  "status": "success",
  "benchmark_time": 0.123,
  "memory_usage_mb": 512,
  "models_loaded": true
}
EOF

# Create mock model-info endpoint
cat > "$TEMP_DIR/model-info.json" << EOF
{
  "models_loaded": true,
  "face_swapper": "InsightFaceFaceSwapper",
  "face_analyser": "InsightFaceFaceAnalyser",
  "memory_usage_mb": 512,
  "environment": "test",
  "container_id": "mock-container"
}
EOF

# Test health endpoint
echo -e "${BLUE}Testing health endpoint...${NC}"
cat "$TEMP_DIR/health.json"
echo ""

# Test benchmark endpoint
echo -e "${BLUE}Testing benchmark endpoint...${NC}"
cat "$TEMP_DIR/benchmark.json"
echo ""

# Test model-info endpoint
echo -e "${BLUE}Testing model-info endpoint...${NC}"
cat "$TEMP_DIR/model-info.json"
echo ""

# Clean up
echo -e "${BLUE}Cleaning up...${NC}"
rm -rf "$TEMP_DIR"

echo ""
echo -e "${GREEN}All mock tests passed!${NC}"
echo -e "${YELLOW}Note: These are mock responses, not actual API calls.${NC}"
echo -e "${YELLOW}To test the real API, build the Docker image and run it.${NC}"

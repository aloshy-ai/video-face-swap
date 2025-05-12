#!/bin/bash
# Simple test script for the Video Face Swap API
# This script tests the health and benchmark endpoints

set -e

# Configuration
API_URL="http://localhost:8080"  # Change this to your actual API URL

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Video Face Swap API - Simple Test Script   ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "${GREEN}API URL: ${NC}$API_URL"
echo ""

# Test health endpoint
echo -e "${BLUE}Testing health endpoint...${NC}"
health_response=$(curl -s $API_URL/health)
echo -e "${GREEN}Response:${NC} $health_response"

# Test benchmark endpoint
echo -e "${BLUE}Testing benchmark endpoint...${NC}"
benchmark_response=$(curl -s $API_URL/benchmark)
echo -e "${GREEN}Response:${NC} $benchmark_response"

# Test model-info endpoint
echo -e "${BLUE}Testing model-info endpoint...${NC}"
model_info_response=$(curl -s $API_URL/model-info)
echo -e "${GREEN}Response:${NC} $model_info_response"

echo ""
echo -e "${GREEN}All tests completed!${NC}"

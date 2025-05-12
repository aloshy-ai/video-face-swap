#!/bin/bash
# Video Face Swap API - Deployment Script
# This script helps with building and deploying the Video Face Swap API to GCP

set -e

# Configuration - modify these variables as needed
PROJECT_ID="video-face-swap-459615"
REGION="us-central1"
VERSION=$(date +%Y%m%d-%H%M%S)
USE_OPTIMIZED=false
TF_DIR="terraform"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}Project ID not set in script. Please enter your GCP Project ID:${NC}"
    read PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Project ID is required. Exiting.${NC}"
        exit 1
    fi
fi

# Print banner
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Video Face Swap API - Deployment Script    ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""
echo -e "${GREEN}Project: ${NC}$PROJECT_ID"
echo -e "${GREEN}Region:  ${NC}$REGION"
echo -e "${GREEN}Version: ${NC}$VERSION"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check for required tools
echo -e "${BLUE}Checking for required tools...${NC}"
MISSING_TOOLS=0

if ! command_exists gcloud; then
    echo -e "${RED}gcloud CLI not found. Please install: https://cloud.google.com/sdk/docs/install${NC}"
    MISSING_TOOLS=1
fi

if ! command_exists docker; then
    echo -e "${RED}Docker not found. Please install: https://docs.docker.com/get-docker/${NC}"
    MISSING_TOOLS=1
fi

if ! command_exists terraform; then
    echo -e "${RED}Terraform not found. Please install: https://learn.hashicorp.com/tutorials/terraform/install-cli${NC}"
    MISSING_TOOLS=1
fi

if [ $MISSING_TOOLS -eq 1 ]; then
    echo -e "${RED}Missing required tools. Please install them and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}All required tools are installed.${NC}"

# Ask for deployment options
echo ""
echo -e "${BLUE}Select deployment options:${NC}"
echo "1) Build and deploy everything (build image, push to Artifact Registry, deploy with Terraform)"
echo "2) Build and push Docker image only"
echo "3) Deploy infrastructure with Terraform only"
echo "4) Display deployment information"
echo "5) Clean up resources"
echo "q) Quit"
echo ""
echo -e "${YELLOW}Enter your choice [1]:${NC}"
read DEPLOY_OPTION
DEPLOY_OPTION=${DEPLOY_OPTION:-1}

# Using the main Dockerfile
DOCKERFILE="Dockerfile"
echo -e "${GREEN}Using Dockerfile${NC}"

# Build and push Docker image
build_and_push_image() {
    echo -e "${BLUE}Building Docker image...${NC}"
    
    # Set up authentication for Artifact Registry
    echo -e "${BLUE}Configuring Docker authentication for Artifact Registry...${NC}"
    gcloud auth configure-docker $REGION-docker.pkg.dev
    
    # Build the image
    echo -e "${BLUE}Building Docker image: $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$VERSION...${NC}"
    docker build --platform linux/amd64 -t $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$VERSION -f $DOCKERFILE .
    
    # Tag as latest
    docker tag $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$VERSION $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:latest
    
    # Push the image
    echo -e "${BLUE}Pushing Docker image to Artifact Registry...${NC}"
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$VERSION
    docker push $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:latest
    
    echo -e "${GREEN}Docker image built and pushed successfully!${NC}"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    echo -e "${BLUE}Deploying infrastructure with Terraform...${NC}"
    
    # Initialize Terraform
    echo -e "${BLUE}Initializing Terraform...${NC}"
    (cd $TF_DIR && terraform init)
    
    # Apply Terraform configuration
    echo -e "${BLUE}Applying Terraform configuration...${NC}"
    (cd $TF_DIR && terraform apply -var "project_id=$PROJECT_ID" -var "region=$REGION" -var "container_image_url=$REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api:$VERSION")
    
    echo -e "${GREEN}Infrastructure deployed successfully!${NC}"
    
    # Get service URL
    SERVICE_URL=$(cd $TF_DIR && terraform output -raw service_url)
    echo -e "${GREEN}Service deployed at: ${NC}$SERVICE_URL"
}

# Display deployment information
display_info() {
    echo -e "${BLUE}Deployment Information:${NC}"
    echo -e "${GREEN}Project ID:   ${NC}$PROJECT_ID"
    echo -e "${GREEN}Region:       ${NC}$REGION"
    echo -e "${GREEN}Version:      ${NC}$VERSION"
    echo -e "${GREEN}Dockerfile:   ${NC}$DOCKERFILE"
    
    # Check if the repository exists
    if gcloud artifacts repositories describe video-face-swap --location=$REGION --project=$PROJECT_ID &> /dev/null; then
        echo -e "${GREEN}Repository:   ${NC}$REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap"
        
        # List images
        echo -e "${GREEN}Images:${NC}"
        gcloud artifacts docker images list $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api --limit=5 2>/dev/null | awk 'NR>1 {print "  - "$1}' || echo "  No images found"
    else
        echo -e "${YELLOW}Repository not found: $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap${NC}"
    fi
    
    # Check if the Cloud Run service exists
    if gcloud run services describe video-face-swap-api --region=$REGION --project=$PROJECT_ID &> /dev/null; then
        SERVICE_URL=$(gcloud run services describe video-face-swap-api --region=$REGION --project=$PROJECT_ID --format="value(status.url)")
        echo -e "${GREEN}Service URL:  ${NC}$SERVICE_URL"
        
        # Get instance count
        INSTANCES=$(gcloud run services describe video-face-swap-api --region=$REGION --project=$PROJECT_ID --format="value(status.traffic.percent)")
        if [ ! -z "$INSTANCES" ]; then
            echo -e "${GREEN}Instances:    ${NC}$INSTANCES% of traffic serving"
        fi
    else
        echo -e "${YELLOW}Service not found: video-face-swap-api${NC}"
    fi
}

# Clean up resources
clean_up() {
    echo -e "${RED}WARNING: This will delete all resources associated with the Video Face Swap API.${NC}"
    echo -e "${YELLOW}Are you sure you want to continue? (y/N)${NC}"
    read CONFIRM
    
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        echo -e "${BLUE}Cleaning up resources...${NC}"
        
        # Delete Cloud Run service
        echo -e "${BLUE}Deleting Cloud Run service...${NC}"
        gcloud run services delete video-face-swap-api --region=$REGION --project=$PROJECT_ID --quiet || true
        
        # Delete Artifact Registry images
        echo -e "${BLUE}Deleting Artifact Registry images...${NC}"
        gcloud artifacts docker images delete $REGION-docker.pkg.dev/$PROJECT_ID/video-face-swap/api --delete-tags --quiet || true
        
        # Delete other resources with Terraform
        echo -e "${BLUE}Destroying Terraform-managed resources...${NC}"
        (cd terraform && terraform destroy -var "project_id=$PROJECT_ID" -var "region=$REGION") || true
        
        echo -e "${GREEN}Cleanup completed.${NC}"
    else
        echo -e "${BLUE}Cleanup cancelled.${NC}"
    fi
}

# Execute selected option
case $DEPLOY_OPTION in
    1)
        build_and_push_image
        deploy_infrastructure
        echo -e "${GREEN}Deployment completed successfully!${NC}"
        ;;
    2)
        build_and_push_image
        echo -e "${GREEN}Build and push completed.${NC}"
        ;;
    3)
        deploy_infrastructure
        echo -e "${GREEN}Infrastructure deployment completed.${NC}"
        ;;
    4)
        display_info
        ;;
    5)
        clean_up
        ;;
    q|Q)
        echo -e "${BLUE}Exiting.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option: $DEPLOY_OPTION${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}=============================================${NC}"
echo -e "${GREEN}Operation completed successfully!${NC}"
echo -e "${BLUE}=============================================${NC}"

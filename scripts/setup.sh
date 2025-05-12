#!/bin/bash
# Video Face Swap API - Setup Script
# This script helps with setting up the required GCP services

set -e

# Configuration
PROJECT_ID=""
REGION="us-central1"

# Color variables
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Print banner
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Video Face Swap API - GCP Setup Script     ${NC}"
echo -e "${BLUE}=============================================${NC}"
echo ""

# Check if project ID is set
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}Project ID not set in script. Please enter your GCP Project ID:${NC}"
    read PROJECT_ID
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}Project ID is required. Exiting.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Project: ${NC}$PROJECT_ID"
echo -e "${GREEN}Region:  ${NC}$REGION"
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

if [ $MISSING_TOOLS -eq 1 ]; then
    echo -e "${RED}Missing required tools. Please install them and try again.${NC}"
    exit 1
fi

echo -e "${GREEN}All required tools are installed.${NC}"

# Ask for confirmation
echo ""
echo -e "${YELLOW}This script will enable required GCP APIs and set up initial resources for the Video Face Swap API.${NC}"
echo -e "${YELLOW}Do you want to continue? (y/N)${NC}"
read CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${BLUE}Setup cancelled.${NC}"
    exit 0
fi

# Check if user is authenticated with gcloud
echo -e "${BLUE}Checking gcloud authentication...${NC}"
GCLOUD_AUTH=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)
if [ -z "$GCLOUD_AUTH" ]; then
    echo -e "${YELLOW}You're not authenticated with gcloud. Initiating login...${NC}"
    gcloud auth login
fi

# Set the project
echo -e "${BLUE}Setting project to $PROJECT_ID...${NC}"
gcloud config set project $PROJECT_ID

# Enable required APIs
echo -e "${BLUE}Enabling required GCP APIs...${NC}"
APIS=(
    "run.googleapis.com"              # Cloud Run
    "artifactregistry.googleapis.com" # Artifact Registry
    "storage.googleapis.com"          # Cloud Storage
    "cloudbuild.googleapis.com"       # Cloud Build
    "iam.googleapis.com"              # IAM
    "monitoring.googleapis.com"       # Cloud Monitoring
    "logging.googleapis.com"          # Cloud Logging
    "secretmanager.googleapis.com"    # Secret Manager (optional)
    "containerscanning.googleapis.com" # Container Scanning
)

for api in "${APIS[@]}"; do
    echo -e "  Enabling $api..."
    gcloud services enable $api --project=$PROJECT_ID
done

# Create Artifact Registry repository
echo -e "${BLUE}Creating Artifact Registry repository...${NC}"
if gcloud artifacts repositories describe video-face-swap --location=$REGION --project=$PROJECT_ID &> /dev/null; then
    echo -e "${YELLOW}Artifact Registry repository 'video-face-swap' already exists.${NC}"
else
    gcloud artifacts repositories create video-face-swap \
        --repository-format=docker \
        --location=$REGION \
        --description="Video Face Swap API repository" \
        --project=$PROJECT_ID
    echo -e "${GREEN}Created Artifact Registry repository 'video-face-swap'.${NC}"
fi

# Create Storage bucket
BUCKET_NAME="${PROJECT_ID}-vfs-temp"
echo -e "${BLUE}Creating Cloud Storage bucket '$BUCKET_NAME'...${NC}"
if gsutil ls -p $PROJECT_ID gs://$BUCKET_NAME &> /dev/null; then
    echo -e "${YELLOW}Cloud Storage bucket '$BUCKET_NAME' already exists.${NC}"
else
    gsutil mb -l $REGION -p $PROJECT_ID gs://$BUCKET_NAME
    echo -e "${GREEN}Created Cloud Storage bucket '$BUCKET_NAME'.${NC}"
    
    # Set lifecycle policy for temporary files
    echo '{
        "rule": [
            {
                "action": {"type": "Delete"},
                "condition": {"age": 1}
            }
        ]
    }' > /tmp/lifecycle_config.json
    
    gsutil lifecycle set /tmp/lifecycle_config.json gs://$BUCKET_NAME
    echo -e "${GREEN}Set lifecycle policy to delete files after 1 day.${NC}"
    
    # Remove the temporary file
    rm /tmp/lifecycle_config.json
fi

# Create service account for the API
SA_NAME="video-face-swap-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
echo -e "${BLUE}Creating service account '$SA_NAME'...${NC}"

if gcloud iam service-accounts describe $SA_EMAIL --project=$PROJECT_ID &> /dev/null; then
    echo -e "${YELLOW}Service account '$SA_EMAIL' already exists.${NC}"
else
    gcloud iam service-accounts create $SA_NAME \
        --display-name="Video Face Swap API Service Account" \
        --description="Used by the Video Face Swap service to access GCP resources" \
        --project=$PROJECT_ID
    echo -e "${GREEN}Created service account '$SA_EMAIL'.${NC}"
fi

# Grant Storage Object Admin role to the service account
echo -e "${BLUE}Granting storage permissions to service account...${NC}"
gsutil iam ch serviceAccount:$SA_EMAIL:objectAdmin gs://$BUCKET_NAME
echo -e "${GREEN}Granted Storage Object Admin role to '$SA_EMAIL' for bucket '$BUCKET_NAME'.${NC}"

echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${BLUE}=============================================${NC}"
echo -e "${BLUE}  Next Steps: ${NC}"
echo -e "${BLUE}  1. Build and deploy the application using: ${NC}"
echo -e "${BLUE}     ./deploy.sh ${NC}"
echo -e "${BLUE}  2. For manual deployment, follow the steps in: ${NC}"
echo -e "${BLUE}     ../docs/deployment_guide.md ${NC}"
echo -e "${BLUE}=============================================${NC}"

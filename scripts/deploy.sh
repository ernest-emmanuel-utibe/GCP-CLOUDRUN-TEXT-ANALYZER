#!/bin/bash

# Manual deployment script for Cloud Text Analyzer
# This script builds, pushes, and deploys the application manually

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGION="us-central1"
SERVICE_NAME="text-analyzer"
REPOSITORY_NAME="text-analyzer-repo"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get project ID
get_project_id() {
    if [ -z "$PROJECT_ID" ]; then
        PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "Could not determine project ID. Set PROJECT_ID environment variable or run 'gcloud config set project YOUR_PROJECT_ID'"
        exit 1
    fi
    
    log_info "Using project: $PROJECT_ID"
}

# Generate image tag
generate_tag() {
    if [ -n "$1" ]; then
        IMAGE_TAG="$1"
    else
        # Use git commit hash if available, otherwise timestamp
        if command -v git &> /dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
            IMAGE_TAG=$(git rev-parse --short HEAD)
        else
            IMAGE_TAG=$(date +%Y%m%d-%H%M%S)
        fi
    fi
    
    log_info "Using image tag: $IMAGE_TAG"
}

# Build Docker image
build_image() {
    log_info "Building Docker image..."
    
    cd app
    
    local image_url="$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:$IMAGE_TAG"
    
    docker build -t "$image_url" .
    docker tag "$image_url" "$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest"
    
    cd ..
    
    log_success "Docker image built successfully"
}

# Configure Docker for Artifact Registry
configure_docker() {
    log_info "Configuring Docker for Artifact Registry..."
    
    gcloud auth configure-docker "$REGION-docker.pkg.dev" --quiet
    
    log_success "Docker configured for Artifact Registry"
}

# Push Docker image
push_image() {
    log_info "Pushing Docker image to Artifact Registry..."
    
    local image_url="$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:$IMAGE_TAG"
    local latest_url="$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest"
    
    docker push "$image_url"
    docker push "$latest_url"
    
    log_success "Docker image pushed successfully"
}

# Deploy with Terraform
deploy_terraform() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd terraform
    
    # Set Google Application Credentials if not already set
    if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -f "../terraform-key.json" ]; then
        export GOOGLE_APPLICATION_CREDENTIALS="../terraform-key.json"
    fi
    
    # Initialize if needed
    if [ ! -d ".terraform" ]; then
        terraform init
    fi
    
    # Plan with the new image tag
    terraform plan -var="project_id=$PROJECT_ID" -var="image_tag=$IMAGE_TAG" -out=tfplan
    
    # Apply
    terraform apply -auto-approve tfplan
    
    cd ..
    
    log_success "Infrastructure deployed successfully"
}

# Get service URL
get_service_url() {
    log_info "Getting Cloud Run service URL..."
    
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(status.url)' 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_URL" ]; then
        log_success "Service deployed at: $SERVICE_URL"
    else
        log_warning "Could not retrieve service URL"
    fi
}

# Test deployment
test_deployment() {
    log_info "Testing deployment..."
    
    if [ -z "$SERVICE_URL" ]; then
        log_warning "No service URL available, skipping tests"
        return
    fi
    
    # Note: This will likely fail because the service is private
    # But we can still check if the service exists and is configured
    
    log_info "Checking service configuration..."
    gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format="table(spec.template.spec.containers[].image,status.conditions[].type:label=CONDITION,status.conditions[].status:label=STATUS)"
    
    log_success "Deployment test completed"
}

# Run health check (if accessible)
health_check() {
    if [ -n "$SERVICE_URL" ]; then
        log_info "Attempting health check (may fail for private services)..."
        
        # Try to access health endpoint
        if curl -f -s "$SERVICE_URL/health" > /dev/null 2>&1; then
            log_success "Health check passed"
        else
            log_warning "Health check failed (expected for private services)"
        fi
    fi
}

# Cleanup old images
cleanup_images() {
    log_info "Cleaning up old Docker images..."
    
    # Remove local images to save space
    docker images | grep "$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME" | awk '{print $3}' | head -n -2 | xargs -r docker rmi 2>/dev/null || true
    
    log_success "Local image cleanup completed"
}

# Show deployment info
show_deployment_info() {
    echo
    log_success "Deployment completed successfully!"
    echo
    log_info "Deployment Information:"
    echo "  Project ID: $PROJECT_ID"
    echo "  Service Name: $SERVICE_NAME"
    echo "  Region: $REGION"
    echo "  Image Tag: $IMAGE_TAG"
    if [ -n "$SERVICE_URL" ]; then
        echo "  Service URL: $SERVICE_URL"
    fi
    echo
    log_info "Useful commands:"
    echo "  View logs: gcloud logs read \"resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME\" --project=$PROJECT_ID"
    echo "  Describe service: gcloud run services describe $SERVICE_NAME --region=$REGION --project=$PROJECT_ID"
    echo "  Update service: gcloud run deploy $SERVICE_NAME --image=$REGION-docker.pkg.dev/$PROJECT_ID/$REPOSITORY_NAME/$SERVICE_NAME:latest --region=$REGION --project=$PROJECT_ID"
    echo
}

# Main deployment function
main() {
    local image_tag="$1"
    
    log_info "Starting manual deployment of Cloud Text Analyzer..."
    
    get_project_id
    generate_tag "$image_tag"
    configure_docker
    build_image
    push_image
    deploy_terraform
    get_service_url
    test_deployment
    health_check
    cleanup_images
    show_deployment_info
}

# Show usage
show_usage() {
    echo "Usage: $0 [IMAGE_TAG]"
    echo ""
    echo "Deploy the Cloud Text Analyzer application manually"
    echo ""
    echo "Arguments:"
    echo "  IMAGE_TAG  Optional. Custom tag for the Docker image (default: git commit hash or timestamp)"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_ID  GCP Project ID (default: from gcloud config)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Deploy with auto-generated tag"
    echo "  $0 v1.0.0            # Deploy with custom tag"
    echo "  PROJECT_ID=my-project $0  # Deploy to specific project"
}

# Handle command line arguments
case "$1" in
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        main "$1"
        ;;
esac
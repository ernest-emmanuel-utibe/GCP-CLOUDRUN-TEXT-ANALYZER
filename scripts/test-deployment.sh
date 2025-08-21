#!/bin/bash

# Test deployment script for Cloud Text Analyzer
# This script validates that the deployment is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="text-analyzer"
REGION="us-central1"

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
    
    log_info "Testing project: $PROJECT_ID"
}

# Check if service exists
check_service_exists() {
    log_info "Checking if Cloud Run service exists..."
    
    if gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$PROJECT_ID" &> /dev/null; then
        log_success "Cloud Run service '$SERVICE_NAME' exists"
    else
        log_error "Cloud Run service '$SERVICE_NAME' not found"
        exit 1
    fi
}

# Get service details
get_service_details() {
    log_info "Getting service details..."
    
    SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(status.url)' 2>/dev/null)
    
    SERVICE_STATUS=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(status.conditions[0].status)' 2>/dev/null)
    
    SERVICE_IMAGE=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(spec.template.spec.containers[0].image)' 2>/dev/null)
    
    echo "  Service URL: $SERVICE_URL"
    echo "  Service Status: $SERVICE_STATUS"
    echo "  Service Image: $SERVICE_IMAGE"
    
    if [ "$SERVICE_STATUS" != "True" ]; then
        log_error "Service is not ready (Status: $SERVICE_STATUS)"
        return 1
    fi
    
    log_success "Service is ready"
}

# Test service configuration
test_service_config() {
    log_info "Testing service configuration..."
    
    # Check ingress settings
    INGRESS=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(metadata.annotations."run.googleapis.com/ingress")' 2>/dev/null)
    
    if [ "$INGRESS" = "internal" ]; then
        log_success "Service is correctly configured for internal traffic only"
    else
        log_warning "Service ingress setting: $INGRESS (expected: internal)"
    fi
    
    # Check VPC connector
    VPC_CONNECTOR=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(spec.template.metadata.annotations."run.googleapis.com/vpc-access-connector")' 2>/dev/null)
    
    if [ -n "$VPC_CONNECTOR" ]; then
        log_success "Service is using VPC connector: $VPC_CONNECTOR"
    else
        log_warning "No VPC connector configured"
    fi
    
    # Check service account
    SERVICE_ACCOUNT=$(gcloud run services describe "$SERVICE_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(spec.template.spec.serviceAccountName)' 2>/dev/null)
    
    if [ -n "$SERVICE_ACCOUNT" ]; then
        log_success "Service is using service account: $SERVICE_ACCOUNT"
    else
        log_warning "No custom service account configured"
    fi
}

# Test via VPC (if possible)
test_via_vpc() {
    log_info "Testing service accessibility..."
    
    # Since the service is private, we'll test by creating a temporary VM
    # in the same VPC and testing from there
    
    log_warning "Service is configured for internal traffic only"
    log_info "To test the API, you would need to access it from within the VPC"
    log_info "You can create a temporary VM or use Cloud Shell with VPC peering"
    
    # Show example curl commands
    echo
    log_info "Example test commands (run from within VPC):"
    echo "  # Health check"
    echo "  curl -X GET '$SERVICE_URL/health'"
    echo
    echo "  # Analyze text"
    echo "  curl -X POST '$SERVICE_URL/analyze' \\"
    echo "       -H 'Content-Type: application/json' \\"
    echo "       -d '{\"text\": \"I love cloud engineering!\"}'"
}

# Test Artifact Registry
test_artifact_registry() {
    log_info "Checking Artifact Registry..."
    
    REPO_EXISTS=$(gcloud artifacts repositories describe "text-analyzer-repo" \
        --location="$REGION" \
        --project="$PROJECT_ID" \
        --format='value(name)' 2>/dev/null || echo "")
    
    if [ -n "$REPO_EXISTS" ]; then
        log_success "Artifact Registry repository exists"
        
        # List images
        log_info "Checking for container images..."
        IMAGES=$(gcloud artifacts docker images list "$REGION-docker.pkg.dev/$PROJECT_ID/text-analyzer-repo" \
            --format='value(IMAGE)' 2>/dev/null || echo "")
        
        if [ -n "$IMAGES" ]; then
            log_success "Container images found:"
            echo "$IMAGES" | while read -r image; do
                echo "  - $image"
            done
        else
            log_warning "No container images found in repository"
        fi
    else
        log_error "Artifact Registry repository not found"
    fi
}

# Test Terraform state
test_terraform_state() {
    log_info "Checking Terraform resources..."
    
    if [ -d "terraform" ] && [ -f "terraform/terraform.tfstate" ]; then
        cd terraform
        
        # Check if Terraform state contains expected resources
        RESOURCES=$(terraform state list 2>/dev/null || echo "")
        
        if [ -n "$RESOURCES" ]; then
            log_success "Terraform state contains $(echo "$RESOURCES" | wc -l) resources"
            
            # Check for key resources
            if echo "$RESOURCES" | grep -q "google_cloud_run_v2_service.text_analyzer"; then
                log_success "Cloud Run service found in Terraform state"
            else
                log_warning "Cloud Run service not found in Terraform state"
            fi
            
            if echo "$RESOURCES" | grep -q "google_artifact_registry_repository.app_repo"; then
                log_success "Artifact Registry repository found in Terraform state"
            else
                log_warning "Artifact Registry repository not found in Terraform state"
            fi
        else
            log_warning "No Terraform resources found (state may be empty or remote)"
        fi
        
        cd ..
    else
        log_warning "Terraform directory or state file not found"
    fi
}

# Show resource costs (approximate)
show_cost_estimate() {
    log_info "Approximate cost estimate:"
    echo "  Cloud Run: Pay per request (first 2M requests free)"
    echo "  VPC Connector: ~$0.036/hour when active"
    echo "  Artifact Registry: ~$0.10/GB/month storage"
    echo "  Compute Engine (VPC): Free tier available"
    echo
    log_info "Total estimated cost: <$5/month for light usage"
}

# Generate test report
generate_report() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat << EOF > deployment-test-report.txt
Cloud Text Analyzer - Deployment Test Report
Generated: $timestamp
Project: $PROJECT_ID
Region: $REGION

Service Details:
- Service Name: $SERVICE_NAME
- Service URL: $SERVICE_URL
- Service Status: $SERVICE_STATUS
- Service Image: $SERVICE_IMAGE
- Ingress: $INGRESS
- VPC Connector: $VPC_CONNECTOR
- Service Account: $SERVICE_ACCOUNT

Test Results:
- Service Exists: ✓
- Service Ready: $([ "$SERVICE_STATUS" = "True" ] && echo "✓" || echo "✗")
- Artifact Registry: $([ -n "$REPO_EXISTS" ] && echo "✓" || echo "✗")
- Container Images: $([ -n "$IMAGES" ] && echo "✓" || echo "✗")

Notes:
- Service is configured for internal traffic only
- External testing requires VPC access
- All infrastructure managed by Terraform

EOF
    
    log_success "Test report saved to: deployment-test-report.txt"
}

# Main test function
main() {
    log_info "Starting deployment test for Cloud Text Analyzer..."
    
    get_project_id
    check_service_exists
    get_service_details
    test_service_config
    test_via_vpc
    test_artifact_registry
    test_terraform_state
    show_cost_estimate
    generate_report
    
    echo
    log_success "Deployment test completed!"
    log_info "Check deployment-test-report.txt for detailed results"
}

# Show usage
show_usage() {
    echo "Usage: $0"
    echo ""
    echo "Test the deployed Cloud Text Analyzer application"
    echo ""
    echo "Environment variables:"
    echo "  PROJECT_ID  GCP Project ID (default: from gcloud config)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Test current project"
    echo "  PROJECT_ID=my-project $0  # Test specific project"
}

# Handle command line arguments
case "$1" in
    -h|--help)
        show_usage
        exit 0
        ;;
    *)
        main
        ;;
esac
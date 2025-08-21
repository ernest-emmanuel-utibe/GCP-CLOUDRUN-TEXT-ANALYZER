#!/bin/bash

# Setup script for Cloud Text Analyzer project
# This script helps set up the initial GCP resources and configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if required tools are installed
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v gcloud &> /dev/null; then
        missing_tools+=("gcloud")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and run this script again."
        exit 1
    fi
    
    log_success "All prerequisites are installed"
}

# Get project ID
get_project_id() {
    if [ -z "$PROJECT_ID" ]; then
        log_info "Enter your GCP Project ID:"
        read -r PROJECT_ID
    fi
    
    if [ -z "$PROJECT_ID" ]; then
        log_error "Project ID cannot be empty"
        exit 1
    fi
    
    log_info "Using project: $PROJECT_ID"
    gcloud config set project "$PROJECT_ID"
}

# Authenticate with Google Cloud
authenticate_gcp() {
    log_info "Checking Google Cloud authentication..."
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
        log_warning "Not authenticated with Google Cloud. Starting authentication..."
        gcloud auth login
    fi
    
    # Set up application default credentials
    if [ ! -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        log_info "Setting up application default credentials..."
        gcloud auth application-default login
    fi
    
    log_success "Google Cloud authentication is set up"
}

# Enable required APIs
enable_apis() {
    log_info "Enabling required Google Cloud APIs..."
    
    local apis=(
        "cloudbuild.googleapis.com"
        "run.googleapis.com"
        "artifactregistry.googleapis.com"
        "compute.googleapis.com"
        "vpcaccess.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        log_info "Enabling $api..."
        gcloud services enable "$api" --project="$PROJECT_ID"
    done
    
    log_success "All required APIs have been enabled"
}

# Create service account for Terraform
create_service_accounts() {
    log_info "Creating service accounts..."
    
    # Terraform service account
    if ! gcloud iam service-accounts describe terraform-sa@"$PROJECT_ID".iam.gserviceaccount.com --project="$PROJECT_ID" &> /dev/null; then
        log_info "Creating Terraform service account..."
        gcloud iam service-accounts create terraform-sa \
            --description="Terraform service account" \
            --display-name="Terraform SA" \
            --project="$PROJECT_ID"
        
        # Grant necessary roles
        local roles=(
            "roles/editor"
            "roles/iam.serviceAccountAdmin"
        )
        
        for role in "${roles[@]}"; do
            gcloud projects add-iam-policy-binding "$PROJECT_ID" \
                --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
                --role="$role"
        done
        
        log_success "Terraform service account created"
    else
        log_info "Terraform service account already exists"
    fi
    
    # Create key for Terraform service account
    if [ ! -f "terraform-key.json" ]; then
        log_info "Creating Terraform service account key..."
        gcloud iam service-accounts keys create terraform-key.json \
            --iam-account=terraform-sa@"$PROJECT_ID".iam.gserviceaccount.com \
            --project="$PROJECT_ID"
        
        log_success "Terraform service account key created"
        log_warning "Keep terraform-key.json secure and do not commit it to version control"
    else
        log_info "Terraform service account key already exists"
    fi
}

# Set up Terraform configuration
setup_terraform() {
    log_info "Setting up Terraform configuration..."
    
    if [ ! -f "terraform/terraform.tfvars" ]; then
        log_info "Creating terraform.tfvars file..."
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        
        # Update with actual project ID
        sed -i.bak "s/your-gcp-project-id/$PROJECT_ID/g" terraform/terraform.tfvars
        rm terraform/terraform.tfvars.bak 2>/dev/null || true
        
        log_success "terraform.tfvars created with project ID: $PROJECT_ID"
        log_info "Please review and update terraform/terraform.tfvars if needed"
    else
        log_info "terraform.tfvars already exists"
    fi
}

# Initialize Terraform
init_terraform() {
    log_info "Initializing Terraform..."
    
    cd terraform
    
    # Set Google Application Credentials
    export GOOGLE_APPLICATION_CREDENTIALS="../terraform-key.json"
    
    terraform init
    
    log_info "Running Terraform plan..."
    terraform plan
    
    cd ..
    
    log_success "Terraform is initialized and ready"
}

# Test local application
test_local_app() {
    log_info "Testing local application..."
    
    cd app
    
    # Check if virtual environment exists
    if [ ! -d "venv" ]; then
        log_info "Creating virtual environment..."
        python3 -m venv venv
    fi
    
    # Activate virtual environment and install dependencies
    source venv/bin/activate
    pip install -r requirements.txt
    pip install pytest pytest-asyncio httpx
    
    # Run tests
    log_info "Running tests..."
    python -m pytest ../tests/ -v
    
    deactivate
    cd ..
    
    log_success "Local application tests passed"
}

# Main setup function
main() {
    log_info "Starting Cloud Text Analyzer setup..."
    
    check_prerequisites
    get_project_id
    authenticate_gcp
    enable_apis
    create_service_accounts
    setup_terraform
    init_terraform
    test_local_app
    
    log_success "Setup completed successfully!"
    echo
    log_info "Next steps:"
    echo "1. Review terraform/terraform.tfvars configuration"
    echo "2. Set up GitHub secrets for CI/CD:"
    echo "   - GCP_PROJECT_ID: $PROJECT_ID"
    echo "   - GCP_SA_KEY: (content of terraform-key.json)"
    echo "3. Push code to GitHub to trigger deployment"
    echo "4. Or run 'terraform apply' manually from the terraform directory"
    echo
    log_warning "Remember to keep terraform-key.json secure and never commit it to version control"
}

# Run main function
main "$@"
# Cloud Text Analyzer - GCP Serverless Application

## Project Overview

This project implements a serverless text analysis application on Google Cloud Platform using Infrastructure as Code principles and automated CI/CD deployment.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │    │   Cloud Build   │    │  Artifact Reg   │
│                 │───▶│                 │───▶│                 │
│ - Python App    │    │ - Build Image   │    │ - Store Images  │
│ - Terraform     │    │ - Run Tests     │    │                 │
│ - CI/CD Config  │    │ - Deploy Infra  │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Cloud Run     │    │   VPC Network   │    │   IAM Roles     │
│                 │    │                 │    │                 │
│ - Text Analyzer │◀───│ - Private Access│◀───│ - Service Acct  │
│ - Non-public    │    │ - Security      │    │ - Least Privs   │
│ - Autoscaling   │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Repository Structure

```
cloud-text-analyzer/
├── app/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile          # Container configuration
├── terraform/
│   ├── main.tf             # Main infrastructure
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # Output values
│   └── terraform.tfvars.example
├── .github/
│   ├── workflows/
│   │   └── deploy.yml      # CI/CD pipeline (GitHub Actions)
│   └── ISSUE_TEMPLATE.md   # Issue template
├── scripts/
│   ├── setup.sh           # Initial setup script
│   ├── deploy.sh          # Manual deployment
│   └── test-deployment.sh # Deployment validation
├── tests/
│   └── test_main.py       # Application tests
├── cloudbuild.yaml        # Google Cloud Build config
├── docker-compose.yml     # Local development
├── Makefile              # Development shortcuts
├── .gitignore           # Git ignore patterns
└── README.md            # This file
```

## Design Decisions

### Why Cloud Run?
- **Serverless**: Pay only for requests, automatic scaling to zero
- **Container-native**: Full control over runtime environment
- **Security**: Built-in security features and VPC integration
- **Simplicity**: Minimal configuration for HTTP services

### Security Approach
- **Private Cloud Run**: No public internet access
- **Service Account**: Dedicated, least-privilege identity
- **VPC Integration**: Network-level isolation
- **IAM**: Role-based access control

### CI/CD Strategy
- **GitHub Actions**: Native GitHub integration
- **Automated Testing**: Code quality and functionality checks
- **Image Tagging**: Git SHA for traceability
- **Terraform State**: Remote state management

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **GitHub Account** with repository access
3. **Local Tools**:
   - `gcloud` CLI
   - `terraform` (>= 1.0)
   - `docker`
   - `git`

## Setup Instructions

### 1. Initial GCP Setup

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Create or select project
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable compute.googleapis.com
```

### 2. Create Service Account for Terraform

```bash
# Create service account
gcloud iam service-accounts create terraform-sa \
    --description="Terraform service account" \
    --display-name="Terraform SA"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:terraform-sa@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/iam.serviceAccountAdmin"

# Create and download key
gcloud iam service-accounts keys create terraform-key.json \
    --iam-account=terraform-sa@$PROJECT_ID.iam.gserviceaccount.com
```

### 3. Repository Setup

```bash
# Clone repository
git clone https://github.com/your-username/GCP-CLOUDRUN-TEXT-ANALYZER.git
cd cloud-text-analyzer

# Copy Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars

# Edit variables
vim terraform/terraform.tfvars
```

### 4. GitHub Secrets Configuration

- `GCP_PROJECT_ID`: Your GCP project ID
- `GCP_SA_KEY`: Content of `terraform-key.json` file
- `TF_API_TOKEN`: Terraform Cloud API token (if using remote state)

### 5. Manual Deployment

```bash
# Initialize Terraform
cd terraform
terraform init

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply

# Test the application
./scripts/test-deployment.sh
```

## Local Development

### Quick Start with Make
```bash
# Install dependencies and run tests
make dev

# Start local development
make run

# Build and test with Docker
make docker-build
make docker-run
```

### Run Application Locally

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload --port 8000

# Test endpoint
curl -X POST http://localhost:8000/analyze \
     -H "Content-Type: application/json" \
     -d '{"text": "I love cloud engineering!"}'
```

### Build Docker Image

```bash
cd app
docker build -t text-analyzer .
docker run -p 8000:8000 text-analyzer
```

### Run Tests

```bash
pip install pytest pytest-asyncio httpx
pytest tests/
```

### Docker Compose Development

```bash
# Start all services
docker-compose up -d

# Run tests in Docker
docker-compose --profile test up test-runner

# Stop services
docker-compose down
```orn main:app --reload --port 8000

# Test endpoint
curl -X POST http://localhost:8000/analyze \
     -H "Content-Type: application/json" \
     -d '{"text": "I love cloud engineering!"}'
```

### Build Docker Image

```bash
cd app
docker build -t text-analyzer .
docker run -p 8000:8000 text-analyzer
```

### Run Tests

```bash
pip install pytest pytest-asyncio httpx
pytest tests/
```

## CI/CD Pipeline

The GitHub Actions workflow automatically:

1. **Linting**: Checks code quality with flake8
2. **Testing**: Runs unit tests with pytest
3. **Build**: Creates Docker image
4. **Push**: Uploads image to Artifact Registry
5. **Deploy**: Updates Cloud Run service with new image

Pipeline triggers on:
- Push to `main` branch
- Pull requests to `main`

## API Usage

### Endpoint: POST /analyze

```bash
curl -X POST https://your-service-url/analyze \
     -H "Content-Type: application/json" \
     -d '{"text": "Hello, Cloud Run!"}'
```

**Response:**
```json
{
  "original_text": "Hello, Cloud Run!",
  "word_count": 3,
  "character_count": 17,
  "analysis_timestamp": "2025-08-21T10:30:00Z"
}
```

## Monitoring and Troubleshooting

### View Logs
```bash
gcloud logs read "resource.type=cloud_run_revision AND resource.labels.service_name=text-analyzer"
```

### Check Service Status
```bash
gcloud run services describe text-analyzer --region=us-central1
```

### Debug Terraform
```bash
terraform plan -detailed-exitcode
terraform apply -auto-approve
```

## Security Considerations

- **No Public Access**: Cloud Run service configured for internal traffic only
- **Least Privilege**: Service account has minimal required permissions
- **Container Security**: Non-root user, minimal base image
- **Secrets Management**: No hardcoded credentials in repository

## Cost Optimization

- **Pay-per-use**: Cloud Run charges only for request processing time
- **Automatic Scaling**: Scales to zero when not in use
- **Resource Limits**: CPU and memory limits prevent cost spikes
- **Regional Deployment**: Single region deployment to minimize data transfer

## Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Make changes and test locally
4. Commit changes: `git commit -am 'Add feature'`
5. Push branch: `git push origin feature-name`
6. Create Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
1. Check existing GitHub Issues
2. Create new issue with detailed description
3. Include logs and error messages
4. Specify environment details

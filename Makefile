# Makefile for Cloud Text Analyzer project
# Simplifies common development and deployment tasks

.PHONY: help install test lint clean build run deploy setup tf-plan tf-apply docker-build docker-run

# Default target
help:
	@echo "Cloud Text Analyzer - Available Commands:"
	@echo ""
	@echo "Development:"
	@echo "  install     Install Python dependencies"
	@echo "  test        Run tests"
	@echo "  lint        Run code linting"
	@echo "  run         Run application locally"
	@echo "  clean       Clean temporary files"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build    Build Docker image"
	@echo "  docker-run      Run Docker container locally"
	@echo "  docker-compose  Start services with docker-compose"
	@echo "  docker-test     Run tests in Docker"
	@echo ""
	@echo "Infrastructure:"
	@echo "  setup       Initial project setup"
	@echo "  tf-init     Initialize Terraform"
	@echo "  tf-plan     Plan Terraform deployment"
	@echo "  tf-apply    Apply Terraform changes"
	@echo "  deploy      Full deployment (build + push + apply)"
	@echo ""
	@echo "Testing:"
	@echo "  test-local      Test local application"
	@echo "  test-deployment Test deployed application"
	@echo ""
	@echo "Cleanup:"
	@echo "  tf-destroy  Destroy Terraform resources"
	@echo "  clean-all   Clean everything"

# Python development
install:
	@echo "Installing Python dependencies..."
	cd app && pip install -r requirements.txt
	pip install pytest pytest-asyncio httpx flake8

test:
	@echo "Running tests..."
	cd app && python -m pytest ../tests/ -v

lint:
	@echo "Running linter..."
	cd app && flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics
	cd app && flake8 . --count --max-complexity=10 --max-line-length=88 --statistics

run:
	@echo "Starting application locally..."
	cd app && uvicorn main:app --reload --port 8000

clean:
	@echo "Cleaning temporary files..."
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +

# Docker development
docker-build:
	@echo "Building Docker image..."
	cd app && docker build -t text-analyzer .

docker-run:
	@echo "Running Docker container..."
	docker run -p 8000:8000 text-analyzer

docker-compose:
	@echo "Starting services with docker-compose..."
	docker-compose up -d

docker-test:
	@echo "Running tests in Docker..."
	docker-compose --profile test up --build test-runner

docker-stop:
	@echo "Stopping Docker services..."
	docker-compose down

# Infrastructure management
setup:
	@echo "Running initial setup..."
	chmod +x scripts/setup.sh
	./scripts/setup.sh

tf-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

tf-plan:
	@echo "Planning Terraform deployment..."
	cd terraform && terraform plan

tf-apply:
	@echo "Applying Terraform changes..."
	cd terraform && terraform apply

tf-destroy:
	@echo "Destroying Terraform resources..."
	cd terraform && terraform destroy

deploy:
	@echo "Running full deployment..."
	chmod +x scripts/deploy.sh
	./scripts/deploy.sh

# Testing
test-local:
	@echo "Testing local application..."
	cd app && python -c "import requests; r = requests.get('http://localhost:8000/health'); print('Health check:', r.status_code, r.json())"
	cd app && python -c "import requests; r = requests.post('http://localhost:8000/analyze', json={'text': 'Hello world'}); print('Analyze test:', r.status_code, r.json())"

test-deployment:
	@echo "Testing deployed application..."
	chmod +x scripts/test-deployment.sh
	./scripts/test-deployment.sh

# Environment setup
env-dev:
	@echo "Setting up development environment..."
	python3 -m venv venv
	. venv/bin/activate && make install

env-activate:
	@echo "Activate virtual environment with: source venv/bin/activate"

# Project maintenance
update-deps:
	@echo "Updating Python dependencies..."
	cd app && pip list --outdated
	@echo "Run 'pip install -U package_name' to update specific packages"

check-security:
	@echo "Checking for security vulnerabilities..."
	cd app && pip-audit

format:
	@echo "Formatting code..."
	cd app && black . --line-length 88
	cd app && isort .

# Cleanup
clean-docker:
	@echo "Cleaning Docker resources..."
	docker system prune -f
	docker volume prune -f

clean-terraform:
	@echo "Cleaning Terraform files..."
	cd terraform && rm -f terraform.tfplan
	cd terraform && rm -f terraform.tfstate.backup

clean-all: clean clean-docker clean-terraform
	@echo "Cleaned all temporary files and resources"

# Development workflow shortcuts
dev: install lint test docker-build
	@echo "Development checks completed"

ci: lint test docker-build
	@echo "CI pipeline simulation completed"

# Quick deployment
quick-deploy: docker-build tf-apply
	@echo "Quick deployment completed"

# Show project status
status:
	@echo "Project Status:"
	@echo "==============="
	@echo ""
	@echo "Python version: $(shell python --version)"
	@echo "Docker version: $(shell docker --version)"
	@echo "Terraform version: $(shell terraform version | head -1)"
	@echo "gcloud version: $(shell gcloud version | head -1)"
	@echo ""
	@echo "Current GCP project: $(shell gcloud config get-value project)"
	@echo ""
	@if [ -f "app/requirements.txt" ]; then \
		echo "Python dependencies:"; \
		cat app/requirements.txt; \
	fi
	@echo ""
	@if [ -d "terraform" ]; then \
		echo "Terraform status:"; \
		cd terraform && terraform workspace show && terraform state list | wc -l | xargs echo "Resources in state:"; \
	fi
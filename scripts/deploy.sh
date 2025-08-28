#!/bin/bash

# OASIS TAXI - Deployment Script
# This script automates the deployment process for the entire application

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENVIRONMENT=${1:-staging}  # Default to staging
SKIP_TESTS=${2:-false}

echo -e "${BLUE}🚀 Starting OASIS TAXI deployment for environment: ${ENVIRONMENT}${NC}"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|staging|production)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Use: development, staging, or production${NC}"
    exit 1
fi

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if required tools are installed
    local tools=("node" "npm" "flutter" "firebase" "terraform" "gcloud")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check Node.js version (require >= 18)
    local node_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_version" -lt 18 ]; then
        log_error "Node.js version 18 or higher is required (current: $(node -v))"
        exit 1
    fi
    
    log_success "All prerequisites are met"
}

# Setup environment variables
setup_environment() {
    log_info "Setting up environment variables for $ENVIRONMENT..."
    
    # Set environment-specific variables
    export NODE_ENV="$ENVIRONMENT"
    export FLUTTER_ENV="$ENVIRONMENT"
    
    # Load environment-specific configuration
    if [ -f "$PROJECT_ROOT/.env.$ENVIRONMENT" ]; then
        set -a
        source "$PROJECT_ROOT/.env.$ENVIRONMENT"
        set +a
        log_success "Environment variables loaded"
    else
        log_warning "No .env.$ENVIRONMENT file found, using defaults"
    fi
}

# Validate configuration
validate_config() {
    log_info "Validating configuration..."
    
    # Check Firebase project
    if [ -z "$FIREBASE_PROJECT_ID" ]; then
        log_error "FIREBASE_PROJECT_ID is not set"
        exit 1
    fi
    
    # Check Google Cloud project
    if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
        log_error "GOOGLE_CLOUD_PROJECT is not set"
        exit 1
    fi
    
    # Verify Firebase login
    if ! firebase projects:list &> /dev/null; then
        log_error "Firebase CLI not authenticated. Run: firebase login"
        exit 1
    fi
    
    # Verify Google Cloud authentication
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n1 &> /dev/null; then
        log_error "Google Cloud CLI not authenticated. Run: gcloud auth login"
        exit 1
    fi
    
    log_success "Configuration validated"
}

# Run tests
run_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log_warning "Skipping tests as requested"
        return
    fi
    
    log_info "Running tests..."
    
    # Backend tests
    if [ -d "$PROJECT_ROOT/backend" ]; then
        log_info "Running backend tests..."
        cd "$PROJECT_ROOT/backend"
        npm test
        log_success "Backend tests passed"
    fi
    
    # Frontend tests
    if [ -d "$PROJECT_ROOT/app" ]; then
        log_info "Running frontend tests..."
        cd "$PROJECT_ROOT/app"
        flutter test
        log_success "Frontend tests passed"
    fi
    
    cd "$PROJECT_ROOT"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    if [ ! -d "$PROJECT_ROOT/terraform" ]; then
        log_warning "No terraform directory found, skipping infrastructure deployment"
        return
    fi
    
    cd "$PROJECT_ROOT/terraform"
    
    # Initialize Terraform
    terraform init
    
    # Create terraform.tfvars if it doesn't exist
    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found, creating from example..."
        if [ -f "terraform.tfvars.example" ]; then
            cp terraform.tfvars.example terraform.tfvars
            log_warning "Please edit terraform.tfvars with your configuration"
        fi
    fi
    
    # Plan and apply
    terraform plan -var-file="terraform.tfvars" -var="environment=$ENVIRONMENT"
    
    if [ "$ENVIRONMENT" = "production" ]; then
        read -p "Apply Terraform changes to PRODUCTION? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warning "Terraform deployment cancelled"
            return
        fi
    fi
    
    terraform apply -auto-approve -var-file="terraform.tfvars" -var="environment=$ENVIRONMENT"
    log_success "Infrastructure deployed"
    
    cd "$PROJECT_ROOT"
}

# Deploy backend (Cloud Functions)
deploy_backend() {
    log_info "Deploying backend (Cloud Functions)..."
    
    if [ ! -d "$PROJECT_ROOT/backend" ]; then
        log_error "Backend directory not found"
        exit 1
    fi
    
    cd "$PROJECT_ROOT/backend"
    
    # Install dependencies
    log_info "Installing backend dependencies..."
    npm ci
    
    # Build the project
    log_info "Building backend..."
    npm run build
    
    # Deploy to Firebase
    log_info "Deploying Cloud Functions..."
    firebase use "$FIREBASE_PROJECT_ID"
    firebase deploy --only functions --project "$FIREBASE_PROJECT_ID"
    
    log_success "Backend deployed"
    cd "$PROJECT_ROOT"
}

# Deploy Firestore rules and indexes
deploy_firestore() {
    log_info "Deploying Firestore rules and indexes..."
    
    # Deploy Firestore rules
    if [ -f "$PROJECT_ROOT/firestore.rules" ]; then
        firebase deploy --only firestore:rules --project "$FIREBASE_PROJECT_ID"
        log_success "Firestore rules deployed"
    fi
    
    # Deploy Firestore indexes
    if [ -f "$PROJECT_ROOT/firestore.indexes.json" ]; then
        firebase deploy --only firestore:indexes --project "$FIREBASE_PROJECT_ID"
        log_success "Firestore indexes deployed"
    fi
    
    # Deploy Storage rules
    if [ -f "$PROJECT_ROOT/storage.rules" ]; then
        firebase deploy --only storage --project "$FIREBASE_PROJECT_ID"
        log_success "Storage rules deployed"
    fi
}

# Build and deploy frontend
deploy_frontend() {
    log_info "Building and deploying frontend..."
    
    if [ ! -d "$PROJECT_ROOT/app" ]; then
        log_error "Frontend directory not found"
        exit 1
    fi
    
    cd "$PROJECT_ROOT/app"
    
    # Get dependencies
    log_info "Getting Flutter dependencies..."
    flutter pub get
    
    # Build for web
    log_info "Building Flutter web app..."
    flutter build web --release --dart-define=ENV="$ENVIRONMENT"
    
    # Deploy to Firebase Hosting
    cd "$PROJECT_ROOT"
    log_info "Deploying to Firebase Hosting..."
    firebase deploy --only hosting --project "$FIREBASE_PROJECT_ID"
    
    log_success "Frontend deployed"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check if functions are accessible
    local api_url="https://us-central1-$FIREBASE_PROJECT_ID.cloudfunctions.net/api/health"
    if curl -f -s "$api_url" > /dev/null; then
        log_success "Backend API is accessible"
    else
        log_warning "Backend API health check failed"
    fi
    
    # Check if hosting is accessible
    local hosting_url="https://$FIREBASE_PROJECT_ID.web.app"
    if curl -f -s "$hosting_url" > /dev/null; then
        log_success "Frontend hosting is accessible"
    else
        log_warning "Frontend hosting health check failed"
    fi
    
    log_success "Deployment verification completed"
}

# Post-deployment tasks
post_deployment() {
    log_info "Running post-deployment tasks..."
    
    # Clear CDN cache if applicable
    if [ "$ENVIRONMENT" = "production" ]; then
        log_info "Consider clearing CDN cache manually if applicable"
    fi
    
    # Send deployment notification (placeholder)
    log_info "Deployment completed successfully!"
    
    # Show important URLs
    echo -e "\n${GREEN}🎉 Deployment Summary:${NC}"
    echo -e "${BLUE}Environment:${NC} $ENVIRONMENT"
    echo -e "${BLUE}Firebase Project:${NC} $FIREBASE_PROJECT_ID"
    echo -e "${BLUE}Frontend URL:${NC} https://$FIREBASE_PROJECT_ID.web.app"
    echo -e "${BLUE}Backend API:${NC} https://us-central1-$FIREBASE_PROJECT_ID.cloudfunctions.net/api"
    echo -e "${BLUE}Firebase Console:${NC} https://console.firebase.google.com/project/$FIREBASE_PROJECT_ID"
}

# Main deployment flow
main() {
    log_info "OASIS TAXI Deployment Script"
    log_info "Environment: $ENVIRONMENT"
    log_info "Skip Tests: $SKIP_TESTS"
    echo
    
    check_prerequisites
    setup_environment
    validate_config
    run_tests
    deploy_infrastructure
    deploy_backend
    deploy_firestore
    deploy_frontend
    verify_deployment
    post_deployment
    
    log_success "🎉 Deployment completed successfully!"
}

# Handle script interruption
trap 'echo -e "\n${RED}❌ Deployment interrupted!${NC}"; exit 1' INT TERM

# Run main function
main "$@"
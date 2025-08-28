#!/bin/bash

# OASIS TAXI - Local Testing Script
# Test the complete application locally using Firebase Emulators

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Check prerequisites for local testing
check_local_prerequisites() {
    log_info "Checking local testing prerequisites..."
    
    local tools=("node" "npm" "flutter" "firebase")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            log_info "Install guide:"
            case $tool in
                "node"|"npm") echo "  - Download from: https://nodejs.org/" ;;
                "flutter") echo "  - Download from: https://flutter.dev/docs/get-started/install" ;;
                "firebase") echo "  - Install with: npm install -g firebase-tools" ;;
            esac
            exit 1
        fi
    done
    
    log_success "All prerequisites are installed"
}

# Setup local environment
setup_local_environment() {
    log_info "Setting up local environment..."
    
    # Create local environment file if it doesn't exist
    if [ ! -f "$PROJECT_ROOT/.env.local" ]; then
        log_info "Creating local environment file..."
        cat > "$PROJECT_ROOT/.env.local" << EOF
# Local Testing Environment
NODE_ENV=development
FLUTTER_ENV=development
FIREBASE_PROJECT_ID=oasis-taxi-local
GOOGLE_CLOUD_PROJECT=oasis-taxi-local

# Local Firebase Emulator Ports
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099
FIREBASE_FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
FIREBASE_FUNCTIONS_EMULATOR_HOST=127.0.0.1:5001
FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199

# MercadoPago Test Credentials (Use test keys)
MERCADOPAGO_ACCESS_TOKEN=TEST-your-test-access-token
MERCADOPAGO_PUBLIC_KEY=TEST-your-test-public-key

# Email/SMS Test Configuration
EMAIL_SERVICE_ENABLED=false
SMS_SERVICE_ENABLED=false
EOF
        log_success "Local environment file created at .env.local"
        log_warning "Please update .env.local with your test credentials"
    fi
    
    # Load environment variables
    set -a
    source "$PROJECT_ROOT/.env.local"
    set +a
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Backend dependencies
    if [ -d "$PROJECT_ROOT/backend" ]; then
        log_info "Installing backend dependencies..."
        cd "$PROJECT_ROOT/backend"
        npm install
        log_success "Backend dependencies installed"
    fi
    
    # Frontend dependencies
    if [ -d "$PROJECT_ROOT/app" ]; then
        log_info "Installing Flutter dependencies..."
        cd "$PROJECT_ROOT/app"
        flutter pub get
        log_success "Flutter dependencies installed"
    fi
    
    cd "$PROJECT_ROOT"
}

# Start Firebase Emulators
start_emulators() {
    log_info "Starting Firebase Emulators..."
    
    # Login to Firebase (if not already logged in)
    if ! firebase projects:list &> /dev/null; then
        log_warning "Please login to Firebase first:"
        log_info "Run: firebase login"
        exit 1
    fi
    
    # Initialize Firebase project for emulators
    if [ ! -f "$PROJECT_ROOT/firebase.json" ]; then
        log_error "Firebase configuration not found"
        exit 1
    fi
    
    log_info "Starting emulators in background..."
    firebase emulators:start --import=./emulator-data --export-on-exit &
    EMULATOR_PID=$!
    
    # Wait for emulators to start
    log_info "Waiting for emulators to start (30 seconds)..."
    sleep 30
    
    # Check if emulators are running
    if curl -s http://localhost:4000 > /dev/null; then
        log_success "Firebase Emulators are running!"
        log_info "Emulator UI: http://localhost:4000"
        log_info "Auth Emulator: http://localhost:9099"
        log_info "Firestore Emulator: http://localhost:8080"
        log_info "Functions Emulator: http://localhost:5001"
        log_info "Storage Emulator: http://localhost:9199"
    else
        log_error "Failed to start emulators"
        exit 1
    fi
}

# Build and run Flutter app
run_flutter_app() {
    log_info "Building and running Flutter app..."
    
    cd "$PROJECT_ROOT/app"
    
    # Choose platform
    echo -e "\n${BLUE}Choose platform to test:${NC}"
    echo "1) Web Browser"
    echo "2) Android Emulator/Device"
    echo "3) iOS Simulator (Mac only)"
    echo "4) Windows Desktop"
    echo "5) All platforms"
    
    read -p "Enter choice (1-5): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            log_info "Running on Web..."
            flutter run -d chrome --dart-define=ENV=development --dart-define=USE_EMULATOR=true
            ;;
        2)
            log_info "Running on Android..."
            flutter run -d android --dart-define=ENV=development --dart-define=USE_EMULATOR=true
            ;;
        3)
            log_info "Running on iOS..."
            if [[ "$OSTYPE" == "darwin"* ]]; then
                flutter run -d ios --dart-define=ENV=development --dart-define=USE_EMULATOR=true
            else
                log_error "iOS testing only available on macOS"
            fi
            ;;
        4)
            log_info "Running on Windows..."
            flutter run -d windows --dart-define=ENV=development --dart-define=USE_EMULATOR=true
            ;;
        5)
            log_info "Choose device from list..."
            flutter devices
            echo "Run: flutter run -d [device-id] --dart-define=ENV=development --dart-define=USE_EMULATOR=true"
            ;;
        *)
            log_warning "Invalid choice, defaulting to web..."
            flutter run -d chrome --dart-define=ENV=development --dart-define=USE_EMULATOR=true
            ;;
    esac
}

# Quick test without emulators (UI only)
quick_ui_test() {
    log_info "Running quick UI test without backend..."
    
    cd "$PROJECT_ROOT/app"
    
    echo -e "\n${BLUE}Quick UI Test - Choose platform:${NC}"
    echo "1) Web Browser"
    echo "2) Android Emulator/Device"
    echo "3) Windows Desktop"
    
    read -p "Enter choice (1-3): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            flutter run -d chrome --dart-define=ENV=development --dart-define=OFFLINE_MODE=true
            ;;
        2)
            flutter run -d android --dart-define=ENV=development --dart-define=OFFLINE_MODE=true
            ;;
        3)
            flutter run -d windows --dart-define=ENV=development --dart-define=OFFLINE_MODE=true
            ;;
        *)
            flutter run -d chrome --dart-define=ENV=development --dart-define=OFFLINE_MODE=true
            ;;
    esac
}

# Test backend functions locally
test_backend() {
    log_info "Testing backend functions..."
    
    cd "$PROJECT_ROOT/backend"
    
    # Run backend tests
    log_info "Running backend tests..."
    npm test
    
    # Build backend
    log_info "Building backend..."
    npm run build
    
    log_success "Backend tests completed"
}

# Clean up function
cleanup() {
    log_info "Cleaning up..."
    if [ ! -z "$EMULATOR_PID" ]; then
        kill $EMULATOR_PID 2>/dev/null || true
    fi
    firebase emulators:stop 2>/dev/null || true
}

# Main menu
show_menu() {
    echo -e "\n${GREEN}🧪 OASIS TAXI - Local Testing Menu${NC}"
    echo "=================================="
    echo "1) Full Test (Backend + Frontend with Emulators)"
    echo "2) Quick UI Test (Frontend only, no backend)"
    echo "3) Backend Test Only"
    echo "4) Start Emulators Only"
    echo "5) Install Dependencies Only"
    echo "6) Check Prerequisites"
    echo "7) Exit"
    echo
}

# Main function
main() {
    log_info "OASIS TAXI Local Testing Tool"
    
    # Setup cleanup trap
    trap cleanup EXIT INT TERM
    
    while true; do
        show_menu
        read -p "Choose option (1-7): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                check_local_prerequisites
                setup_local_environment
                install_dependencies
                test_backend
                start_emulators
                run_flutter_app
                ;;
            2)
                check_local_prerequisites
                setup_local_environment
                install_dependencies
                quick_ui_test
                ;;
            3)
                check_local_prerequisites
                setup_local_environment
                install_dependencies
                test_backend
                ;;
            4)
                check_local_prerequisites
                setup_local_environment
                start_emulators
                log_info "Emulators are running. Press Ctrl+C to stop."
                read -p "Press Enter to stop emulators..."
                ;;
            5)
                check_local_prerequisites
                setup_local_environment
                install_dependencies
                ;;
            6)
                check_local_prerequisites
                ;;
            7)
                log_info "Goodbye!"
                exit 0
                ;;
            *)
                log_warning "Invalid option. Please choose 1-7."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
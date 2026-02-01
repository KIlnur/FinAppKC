#!/bin/bash
# ============================================================
# FinAppKC Build Script
# Builds plugins, themes, and Docker image
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
BUILD_PLUGINS=true
BUILD_THEMES=true
BUILD_IMAGE=true
SKIP_TESTS=false
IMAGE_TAG="finappkc:latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --plugins-only)
            BUILD_THEMES=false
            BUILD_IMAGE=false
            shift
            ;;
        --themes-only)
            BUILD_PLUGINS=false
            BUILD_IMAGE=false
            shift
            ;;
        --image-only)
            BUILD_PLUGINS=false
            BUILD_THEMES=false
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --plugins-only  Build only Kotlin plugins"
            echo "  --themes-only   Build only Keycloakify themes"
            echo "  --image-only    Build only Docker image (requires pre-built artifacts)"
            echo "  --skip-tests    Skip running tests"
            echo "  --tag TAG       Docker image tag (default: finappkc:latest)"
            echo "  -h, --help      Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Build plugins
if [ "$BUILD_PLUGINS" = true ]; then
    log_info "Building Kotlin plugins..."
    cd "$ROOT_DIR/kc-plugins"
    
    if [ "$SKIP_TESTS" = true ]; then
        ./gradlew shadowJar -x test
    else
        ./gradlew build shadowJar
    fi
    
    log_info "Plugins built successfully"
    ls -la build/libs/*.jar
fi

# Build themes
if [ "$BUILD_THEMES" = true ]; then
    log_info "Building Keycloakify themes..."
    cd "$ROOT_DIR/kc-themes"
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        log_info "Installing npm dependencies..."
        npm ci
    fi
    
    if [ "$SKIP_TESTS" = true ]; then
        npm run build:keycloak
    else
        npm run lint
        npm run typecheck
        npm run build:keycloak
    fi
    
    log_info "Themes built successfully"
    ls -la build_keycloak/target/*.jar 2>/dev/null || log_warn "Theme JAR not found"
fi

# Build Docker image
if [ "$BUILD_IMAGE" = true ]; then
    log_info "Building Docker image: $IMAGE_TAG"
    cd "$ROOT_DIR"
    
    docker build \
        -t "$IMAGE_TAG" \
        -f kc-server/Dockerfile \
        .
    
    log_info "Docker image built successfully: $IMAGE_TAG"
    docker images "$IMAGE_TAG"
fi

log_info "Build completed successfully!"

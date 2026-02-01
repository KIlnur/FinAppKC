#!/bin/bash
# ============================================================
# FinAppKC - Full Project Startup Script (Unix/Linux/macOS)
# ============================================================
#
# Usage:
#   ./start.sh                     # Basic startup (Keycloak + PostgreSQL)
#   ./start.sh --with-mail         # + MailHog for email testing
#   ./start.sh --with-monitoring   # + Grafana, Prometheus, Loki
#   ./start.sh --full              # All services
#   ./start.sh --skip-build        # Skip plugin/theme build
#   ./start.sh --clean             # Clean build before starting
#   ./start.sh --stop              # Stop all services
#   ./start.sh --status            # Show status of all services
#
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$ROOT_DIR/infra"

# Parse arguments
SKIP_BUILD=false
CLEAN=false
WITH_MAIL=false
WITH_MONITORING=false
WITH_OBSERVABILITY=false
FULL=false
STOP=false
STATUS=false
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-build) SKIP_BUILD=true; shift ;;
        --clean|--rebuild) CLEAN=true; shift ;;
        --with-mail) WITH_MAIL=true; shift ;;
        --with-monitoring) WITH_MONITORING=true; shift ;;
        --with-observability) WITH_OBSERVABILITY=true; shift ;;
        --full) FULL=true; shift ;;
        --stop) STOP=true; shift ;;
        --status) STATUS=true; shift ;;
        --logs) SHOW_LOGS=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-build        Skip building plugins and themes"
            echo "  --clean, --rebuild  Clean build directories before building"
            echo "  --with-mail         Start MailHog for email testing"
            echo "  --with-monitoring   Start Grafana, Prometheus, Loki"
            echo "  --with-observability Start Jaeger, OpenTelemetry Collector"
            echo "  --full              Start all services"
            echo "  --stop              Stop all services"
            echo "  --status            Show status of all services"
            echo "  --logs              Follow logs"
            echo "  -h, --help          Show this help message"
            exit 0
            ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  FinAppKC - Enterprise Keycloak IDP${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ==================== Stop Command ====================
if [ "$STOP" = true ]; then
    log_info "Stopping all FinAppKC services..."
    cd "$INFRA_DIR"
    docker-compose --profile mail --profile monitoring --profile observability down
    log_info "All services stopped"
    exit 0
fi

# ==================== Status Command ====================
if [ "$STATUS" = true ]; then
    log_info "FinAppKC Services Status:"
    echo ""
    docker ps --filter "name=finappkc" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    exit 0
fi

# ==================== Logs Command ====================
if [ "$SHOW_LOGS" = true ]; then
    cd "$INFRA_DIR"
    docker-compose logs -f
    exit 0
fi

# ==================== Prerequisites Check ====================
log_step "Checking prerequisites..."

# Check Java
if command -v java &> /dev/null; then
    JAVA_VER=$(java -version 2>&1 | head -n 1)
    log_info "Java: $JAVA_VER"
else
    log_error "Java not found! Please install JDK 21+"
    echo "Download: https://adoptium.net/"
    exit 1
fi

# Check Node.js
if command -v node &> /dev/null; then
    NODE_VER=$(node --version)
    log_info "Node.js: $NODE_VER"
else
    log_error "Node.js not found! Please install Node.js 20+"
    echo "Download: https://nodejs.org/"
    exit 1
fi

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VER=$(docker --version)
    log_info "Docker: $DOCKER_VER"
else
    log_error "Docker not found! Please install Docker"
    exit 1
fi

# Check Docker is running
if ! docker info &> /dev/null; then
    log_error "Docker daemon is not running! Please start Docker"
    exit 1
fi
log_info "Docker daemon is running"

echo ""

# ==================== Clean (optional) ====================
if [ "$CLEAN" = true ]; then
    log_step "Cleaning previous builds..."
    
    rm -rf "$ROOT_DIR/kc-plugins/build"
    rm -rf "$ROOT_DIR/kc-themes/dist"
    rm -rf "$ROOT_DIR/kc-themes/dist_keycloak"
    
    log_info "Clean completed"
fi

# ==================== Build Plugins ====================
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo -e "${CYAN}--------------------------------------------${NC}"
    log_step "Building Kotlin plugins..."
    echo -e "${CYAN}--------------------------------------------${NC}"
    
    cd "$ROOT_DIR/kc-plugins"
    
    # Create gradle wrapper if not exists
    if [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
        log_info "Initializing Gradle wrapper..."
        if command -v gradle &> /dev/null; then
            gradle wrapper --gradle-version 8.6
        else
            log_warn "Gradle not found, downloading wrapper..."
            mkdir -p gradle/wrapper
            curl -fsSL -o gradle/wrapper/gradle-wrapper.jar \
                "https://raw.githubusercontent.com/gradle/gradle/v8.6.0/gradle/wrapper/gradle-wrapper.jar"
        fi
    fi
    
    # Make gradlew executable
    chmod +x gradlew
    
    # Build
    log_info "Running Gradle build..."
    ./gradlew clean shadowJar --no-daemon
    
    log_info "Plugins built successfully"
    ls -la build/libs/*.jar 2>/dev/null || true
fi

# ==================== Build Themes ====================
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo -e "${CYAN}--------------------------------------------${NC}"
    log_step "Building Keycloakify themes..."
    echo -e "${CYAN}--------------------------------------------${NC}"
    
    cd "$ROOT_DIR/kc-themes"
    
    # Install dependencies
    log_info "Installing npm dependencies..."
    npm ci --loglevel=error 2>/dev/null || npm install --loglevel=error
    
    # Build theme
    log_info "Building Keycloakify theme..."
    npm run build
    npx keycloakify build
    
    log_info "Themes built successfully"
fi

# ==================== Setup Environment ====================
echo ""
echo -e "${CYAN}--------------------------------------------${NC}"
log_step "Setting up environment..."
echo -e "${CYAN}--------------------------------------------${NC}"

cd "$INFRA_DIR"

# Create .env from example if not exists
if [ ! -f ".env" ]; then
    log_info "Creating .env from env.example..."
    cp env.example .env
    log_warn ".env file created. Review and modify for production!"
fi

# Create providers directory
PROVIDERS_DIR="$ROOT_DIR/kc-server/providers"
mkdir -p "$PROVIDERS_DIR"

# Copy plugin JAR to providers
log_info "Copying plugin JAR to providers..."
PLUGIN_JAR=$(find "$ROOT_DIR/kc-plugins/build/libs" -name "*-all.jar" 2>/dev/null | head -1)
if [ -z "$PLUGIN_JAR" ]; then
    PLUGIN_JAR=$(find "$ROOT_DIR/kc-plugins/build/libs" -name "*.jar" ! -name "*-sources.jar" ! -name "*-javadoc.jar" 2>/dev/null | head -1)
fi
if [ -n "$PLUGIN_JAR" ]; then
    cp "$PLUGIN_JAR" "$PROVIDERS_DIR/finappkc-plugins.jar"
    echo "  -> Copied $(basename "$PLUGIN_JAR")"
fi

# Copy theme JAR to providers
log_info "Copying theme JAR to providers..."
THEME_JAR="$ROOT_DIR/kc-themes/dist_keycloak/keycloak-theme-for-kc-22-to-25.jar"
if [ -f "$THEME_JAR" ]; then
    cp "$THEME_JAR" "$PROVIDERS_DIR/finappkc-themes.jar"
    echo "  -> Copied $(basename "$THEME_JAR")"
else
    log_warn "Theme JAR not found, using default themes"
fi

# ==================== Determine Profiles ====================
PROFILES=""

if [ "$FULL" = true ]; then
    PROFILES="--profile mail --profile monitoring --profile observability"
else
    if [ "$WITH_MAIL" = true ]; then PROFILES="$PROFILES --profile mail"; fi
    if [ "$WITH_MONITORING" = true ]; then PROFILES="$PROFILES --profile monitoring"; fi
    if [ "$WITH_OBSERVABILITY" = true ]; then PROFILES="$PROFILES --profile observability"; fi
fi

# ==================== Start Docker Compose ====================
echo ""
echo -e "${CYAN}--------------------------------------------${NC}"
log_step "Starting Docker Compose..."
echo -e "${CYAN}--------------------------------------------${NC}"

# Stop existing containers
log_info "Stopping existing containers..."
docker-compose --profile mail --profile monitoring --profile observability down 2>/dev/null || true

# Start services
if [ -n "$PROFILES" ]; then
    log_info "Starting services with profiles..."
    docker-compose $PROFILES up -d
else
    log_info "Starting core services (Keycloak + PostgreSQL)..."
    docker-compose up -d
fi

# ==================== Wait for Keycloak ====================
echo ""
log_info "Waiting for Keycloak to be ready..."
echo "This may take 1-2 minutes on first start..."

MAX_ATTEMPTS=60
ATTEMPT=0
READY=false

while [ "$READY" = false ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    if curl -sf http://localhost:9000/health/ready > /dev/null 2>&1; then
        READY=true
    else
        echo -n "."
        sleep 3
    fi
done

echo ""

if [ "$READY" = true ]; then
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  FinAppKC is ready!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo -e "${WHITE}  KEYCLOAK${NC}"
    echo -e "${GRAY}  -----------------------------------------${NC}"
    echo -e "  Admin Console:    ${CYAN}http://localhost:8080/admin${NC}"
    echo -e "  Account Console:  ${CYAN}http://localhost:8080/realms/finapp/account${NC}"
    echo -e "  Credentials:      ${YELLOW}admin / admin${NC}"
    echo ""
    echo -e "  Health Check:     http://localhost:9000/health"
    echo -e "  Metrics:          http://localhost:9000/metrics"
    echo ""
    
    if [ "$WITH_MAIL" = true ] || [ "$FULL" = true ]; then
        echo -e "${WHITE}  MAILHOG (Email Testing)${NC}"
        echo -e "${GRAY}  -----------------------------------------${NC}"
        echo -e "  Web UI:           ${CYAN}http://localhost:8025${NC}"
        echo -e "  SMTP:             localhost:1025"
        echo ""
    fi
    
    if [ "$WITH_MONITORING" = true ] || [ "$FULL" = true ]; then
        echo -e "${WHITE}  MONITORING${NC}"
        echo -e "${GRAY}  -----------------------------------------${NC}"
        echo -e "  Grafana:          ${CYAN}http://localhost:3000${NC}"
        echo -e "                    admin / admin"
        echo -e "  Prometheus:       http://localhost:9090"
        echo -e "  Loki:             http://localhost:3100"
        echo ""
        echo -e "${WHITE}  Dashboards:${NC}"
        echo -e "  - Audit:          ${YELLOW}http://localhost:3000/d/keycloak-audit${NC}"
        echo -e "  - System:         ${YELLOW}http://localhost:3000/d/keycloak-system${NC}"
        echo ""
    fi
    
    if [ "$WITH_OBSERVABILITY" = true ] || [ "$FULL" = true ]; then
        echo -e "${WHITE}  OBSERVABILITY (Tracing)${NC}"
        echo -e "${GRAY}  -----------------------------------------${NC}"
        echo -e "  Jaeger UI:        ${CYAN}http://localhost:16686${NC}"
        echo -e "  OTLP gRPC:        localhost:4317"
        echo ""
    fi
    
    echo -e "${WHITE}  COMMANDS${NC}"
    echo -e "${GRAY}  -----------------------------------------${NC}"
    echo -e "  Logs:             ./start.sh --logs"
    echo -e "  Status:           ./start.sh --status"
    echo -e "  Stop:             ./start.sh --stop"
    echo ""
else
    log_error "Keycloak failed to start within timeout!"
    echo ""
    echo "Check logs with: docker-compose logs keycloak"
    exit 1
fi

cd "$ROOT_DIR"

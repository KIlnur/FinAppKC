#!/bin/bash
# ============================================================
# FinAppKC Development Environment Script
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

cd "$ROOT_DIR/infra"

case "${1:-start}" in
    start)
        log_info "Starting development environment..."
        
        # Build plugins first
        log_info "Building plugins..."
        cd "$ROOT_DIR/kc-plugins"
        ./gradlew shadowJar -x test
        
        # Start containers
        cd "$ROOT_DIR/infra"
        docker-compose up -d
        
        log_info "Waiting for Keycloak to be ready..."
        until curl -sf http://localhost:8080/health/ready > /dev/null 2>&1; do
            sleep 5
            echo -n "."
        done
        echo ""
        
        log_info "Development environment is ready!"
        log_info "Keycloak Admin: http://localhost:8080/admin"
        log_info "Credentials: admin / admin"
        ;;
    
    stop)
        log_info "Stopping development environment..."
        docker-compose down
        ;;
    
    restart)
        log_info "Restarting development environment..."
        docker-compose restart keycloak
        ;;
    
    logs)
        docker-compose logs -f "${2:-keycloak}"
        ;;
    
    rebuild)
        log_info "Rebuilding and restarting..."
        
        # Rebuild plugins
        cd "$ROOT_DIR/kc-plugins"
        ./gradlew shadowJar -x test
        
        # Restart keycloak
        cd "$ROOT_DIR/infra"
        docker-compose restart keycloak
        ;;
    
    clean)
        log_info "Cleaning up..."
        docker-compose down -v
        log_info "Volumes removed"
        ;;
    
    status)
        docker-compose ps
        ;;
    
    *)
        echo "Usage: $0 {start|stop|restart|logs|rebuild|clean|status}"
        exit 1
        ;;
esac

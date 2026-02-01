#!/bin/bash
# ============================================================
# FinAppKC Monitoring Stack Startup Script
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_PATH="$SCRIPT_DIR/../infra"

cd "$INFRA_PATH"

echo "=========================================="
echo "  FinAppKC Monitoring Stack"
echo "=========================================="
echo ""

case "${1:-}" in
    stop)
        echo "[STOP] Stopping monitoring services..."
        docker-compose -f docker-compose.monitoring.yml down
        echo "[OK] Monitoring stopped"
        exit 0
        ;;
    restart)
        echo "[RESTART] Restarting monitoring services..."
        docker-compose -f docker-compose.monitoring.yml restart
        echo "[OK] Monitoring restarted"
        exit 0
        ;;
    logs)
        echo "[LOGS] Showing monitoring logs..."
        docker-compose -f docker-compose.monitoring.yml logs -f
        exit 0
        ;;
esac

# Check if main stack is running
if ! docker ps --filter "name=finappkc-keycloak" --format "{{.Names}}" | grep -q "finappkc-keycloak"; then
    echo "[WARN] Keycloak is not running. Start main stack first:"
    echo "       ./start.sh"
    echo ""
fi

echo "[1/4] Starting Prometheus..."
docker-compose -f docker-compose.monitoring.yml up -d prometheus

echo "[2/4] Starting Loki..."
docker-compose -f docker-compose.monitoring.yml up -d loki

echo "[3/4] Starting PostgreSQL Exporter..."
docker-compose -f docker-compose.monitoring.yml up -d postgres-exporter

echo "[4/4] Starting Grafana..."
docker-compose -f docker-compose.monitoring.yml up -d grafana

echo ""
echo "=========================================="
echo "  Monitoring Stack Started!"
echo "=========================================="
echo ""
echo "  Services:"
echo "  -----------------------------------------"
echo "  Grafana:      http://localhost:3000"
echo "                admin / admin"
echo ""
echo "  Prometheus:   http://localhost:9090"
echo "  Loki:         http://localhost:3100"
echo ""
echo "  Dashboards:"
echo "  -----------------------------------------"
echo "  Audit:        http://localhost:3000/d/keycloak-audit"
echo "  System:       http://localhost:3000/d/keycloak-system"
echo ""
echo "  Commands:"
echo "  -----------------------------------------"
echo "  Stop:         ./scripts/start-monitoring.sh stop"
echo "  Restart:      ./scripts/start-monitoring.sh restart"
echo "  Logs:         ./scripts/start-monitoring.sh logs"
echo ""

# Wait for Grafana
echo "Waiting for Grafana to be ready..."
for i in {1..30}; do
    if curl -sf http://localhost:3000/api/health > /dev/null 2>&1; then
        echo "[OK] Grafana is ready!"
        break
    fi
    sleep 2
    echo -n "."
done
echo ""

# Open browser (Linux/macOS)
if command -v xdg-open &> /dev/null; then
    xdg-open "http://localhost:3000/d/keycloak-audit" &
elif command -v open &> /dev/null; then
    open "http://localhost:3000/d/keycloak-audit" &
fi

# ============================================================
# FinAppKC Monitoring Stack Startup Script
# ============================================================

param(
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Logs
)

$ErrorActionPreference = "Stop"
$InfraPath = Join-Path $PSScriptRoot "..\infra"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  FinAppKC Monitoring Stack" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

Set-Location $InfraPath

if ($Stop) {
    Write-Host "[STOP] Stopping monitoring services..." -ForegroundColor Yellow
    docker-compose -f docker-compose.monitoring.yml down
    Write-Host "[OK] Monitoring stopped" -ForegroundColor Green
    exit 0
}

if ($Restart) {
    Write-Host "[RESTART] Restarting monitoring services..." -ForegroundColor Yellow
    docker-compose -f docker-compose.monitoring.yml restart
    Write-Host "[OK] Monitoring restarted" -ForegroundColor Green
    exit 0
}

if ($Logs) {
    Write-Host "[LOGS] Showing monitoring logs..." -ForegroundColor Yellow
    docker-compose -f docker-compose.monitoring.yml logs -f
    exit 0
}

# Check if main stack is running
$kcContainer = docker ps --filter "name=finappkc-keycloak" --format "{{.Names}}" 2>$null
if (-not $kcContainer) {
    Write-Host "[WARN] Keycloak is not running. Start main stack first:" -ForegroundColor Yellow
    Write-Host "       .\start.ps1" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "[1/4] Starting Prometheus..." -ForegroundColor Cyan
docker-compose -f docker-compose.monitoring.yml up -d prometheus

Write-Host "[2/4] Starting Loki..." -ForegroundColor Cyan
docker-compose -f docker-compose.monitoring.yml up -d loki

Write-Host "[3/4] Starting PostgreSQL Exporter..." -ForegroundColor Cyan
docker-compose -f docker-compose.monitoring.yml up -d postgres-exporter

Write-Host "[4/4] Starting Grafana..." -ForegroundColor Cyan
docker-compose -f docker-compose.monitoring.yml up -d grafana

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Monitoring Stack Started!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Services:" -ForegroundColor White
Write-Host "  -----------------------------------------" -ForegroundColor Gray
Write-Host "  Grafana:      http://localhost:3000" -ForegroundColor Cyan
Write-Host "                admin / admin" -ForegroundColor Gray
Write-Host ""
Write-Host "  Prometheus:   http://localhost:9090" -ForegroundColor Cyan
Write-Host "  Loki:         http://localhost:3100" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Dashboards:" -ForegroundColor White
Write-Host "  -----------------------------------------" -ForegroundColor Gray
Write-Host "  Audit:        http://localhost:3000/d/keycloak-audit" -ForegroundColor Yellow
Write-Host "  System:       http://localhost:3000/d/keycloak-system" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Commands:" -ForegroundColor White
Write-Host "  -----------------------------------------" -ForegroundColor Gray
Write-Host "  Stop:         .\scripts\start-monitoring.ps1 -Stop" -ForegroundColor Gray
Write-Host "  Restart:      .\scripts\start-monitoring.ps1 -Restart" -ForegroundColor Gray
Write-Host "  Logs:         .\scripts\start-monitoring.ps1 -Logs" -ForegroundColor Gray
Write-Host ""

# Wait for Grafana to be ready
Write-Host "Waiting for Grafana to be ready..." -ForegroundColor Gray
$maxAttempts = 30
$attempt = 0
while ($attempt -lt $maxAttempts) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "[OK] Grafana is ready!" -ForegroundColor Green
            break
        }
    } catch {}
    Start-Sleep -Seconds 2
    $attempt++
    Write-Host "." -NoNewline
}

if ($attempt -eq $maxAttempts) {
    Write-Host ""
    Write-Host "[WARN] Grafana may still be starting. Check docker logs." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Opening Grafana in browser..." -ForegroundColor Cyan
Start-Process "http://localhost:3000/d/keycloak-audit"

# ============================================================
# FinAppKC - Full Project Startup Script (Windows PowerShell)
# ============================================================
#
# Usage:
#   .\start.ps1                    # Core services (Keycloak + PostgreSQL)
#   .\start.ps1 -WithMail          # + MailHog for email testing
#   .\start.ps1 -WithMonitoring    # + Grafana, Prometheus, Loki
#   .\start.ps1 -Full              # All services
#   .\start.ps1 -SkipBuild         # Skip plugin/theme build
#   .\start.ps1 -Clean             # Clean build before starting
#   .\start.ps1 -Stop              # Stop all services
#   .\start.ps1 -Status            # Show status of all services
#
# ============================================================

param(
    [switch]$SkipBuild,
    [switch]$Clean,
    [switch]$Rebuild,
    [switch]$WithMail,
    [switch]$WithMonitoring,
    [switch]$WithObservability,
    [switch]$Full,
    [switch]$Stop,
    [switch]$Status,
    [switch]$Logs
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Info { Write-Host "[INFO] $args" -ForegroundColor Green }
function Write-Warn { Write-Host "[WARN] $args" -ForegroundColor Yellow }
function Write-Err { Write-Host "[ERROR] $args" -ForegroundColor Red }
function Write-Step { Write-Host "[STEP] $args" -ForegroundColor Cyan }

$ROOT_DIR = $PSScriptRoot
$INFRA_DIR = Join-Path $ROOT_DIR "infra"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  FinAppKC - Enterprise Keycloak IDP" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ==================== Stop Command ====================
if ($Stop) {
    Write-Info "Stopping all FinAppKC services..."
    Set-Location $INFRA_DIR
    docker-compose --profile mail --profile monitoring --profile observability down
    Write-Info "All services stopped"
    Set-Location $ROOT_DIR
    exit 0
}

# ==================== Status Command ====================
if ($Status) {
    Write-Info "FinAppKC Services Status:"
    Write-Host ""
    docker ps --filter "name=finappkc" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    Write-Host ""
    exit 0
}

# ==================== Logs Command ====================
if ($Logs) {
    Set-Location $INFRA_DIR
    docker-compose logs -f keycloak
    Set-Location $ROOT_DIR
    exit 0
}

# ==================== Prerequisites Check ====================
Write-Step "Checking prerequisites..."

# Check Java
try {
    $javaPath = Get-Command java -ErrorAction Stop
    $javaOutput = cmd /c "java -version 2>&1"
    $javaVersion = $javaOutput | Select-Object -First 1
    Write-Info "Java: $javaVersion"
} catch {
    Write-Err "Java not found! Please install JDK 21+"
    Write-Host "Download: https://adoptium.net/"
    exit 1
}

# Check Node.js
try {
    $nodeVersion = & node --version
    Write-Info "Node.js: $nodeVersion"
} catch {
    Write-Err "Node.js not found! Please install Node.js 20+"
    Write-Host "Download: https://nodejs.org/"
    exit 1
}

# Check Docker
try {
    $dockerVersion = & docker --version
    Write-Info "Docker: $dockerVersion"
} catch {
    Write-Err "Docker not found! Please install Docker Desktop"
    Write-Host "Download: https://www.docker.com/products/docker-desktop/"
    exit 1
}

# Check Docker is running
$ErrorActionPreference = "SilentlyContinue"
$dockerInfo = & docker info 2>&1 | Out-String
$ErrorActionPreference = "Stop"
if ($dockerInfo -match "Server Version") {
    Write-Info "Docker daemon is running"
} else {
    Write-Err "Docker daemon is not running! Please start Docker Desktop"
    exit 1
}

Write-Host ""

# ==================== Clean (optional) ====================
if ($Clean -or $Rebuild) {
    Write-Step "Cleaning previous builds..."
    
    # Clean plugins
    if (Test-Path "$ROOT_DIR\kc-plugins\build") {
        Remove-Item -Recurse -Force "$ROOT_DIR\kc-plugins\build"
    }
    
    # Clean themes
    if (Test-Path "$ROOT_DIR\kc-themes\dist") {
        Remove-Item -Recurse -Force "$ROOT_DIR\kc-themes\dist"
    }
    if (Test-Path "$ROOT_DIR\kc-themes\dist_keycloak") {
        Remove-Item -Recurse -Force "$ROOT_DIR\kc-themes\dist_keycloak"
    }
    
    Write-Info "Clean completed"
}

# ==================== Build Plugins ====================
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "--------------------------------------------" -ForegroundColor Cyan
    Write-Step "Building Kotlin plugins..."
    Write-Host "--------------------------------------------" -ForegroundColor Cyan
    
    Set-Location "$ROOT_DIR\kc-plugins"
    
    # Create gradle wrapper if not exists
    if (-not (Test-Path "gradle\wrapper\gradle-wrapper.jar")) {
        Write-Info "Downloading Gradle wrapper..."
        New-Item -ItemType Directory -Path "gradle\wrapper" -Force | Out-Null
        
        $wrapperUrl = "https://raw.githubusercontent.com/gradle/gradle/v8.6.0/gradle/wrapper/gradle-wrapper.jar"
        Invoke-WebRequest -Uri $wrapperUrl -OutFile "gradle\wrapper\gradle-wrapper.jar" -UseBasicParsing
        
        $propsContent = @"
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-bin.zip
networkTimeout=10000
validateDistributionUrl=true
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
"@
        Set-Content -Path "gradle\wrapper\gradle-wrapper.properties" -Value $propsContent
        Write-Info "Gradle wrapper downloaded"
    }
    
    # Build
    Write-Info "Running Gradle build..."
    & .\gradlew.bat clean shadowJar --no-daemon
    
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Plugin build failed!"
        exit 1
    }
    
    Write-Info "Plugins built successfully"
    Get-ChildItem "build\libs\*.jar" | ForEach-Object { Write-Host "  -> $($_.Name)" -ForegroundColor Gray }
}

# ==================== Build Themes ====================
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "--------------------------------------------" -ForegroundColor Cyan
    Write-Step "Building Keycloakify login theme..."
    Write-Host "--------------------------------------------" -ForegroundColor Cyan
    
    Set-Location "$ROOT_DIR\kc-themes"
    
    # Install dependencies
    Write-Info "Installing npm dependencies..."
    & npm install --loglevel=error
    if ($LASTEXITCODE -ne 0) {
        Write-Err "npm install failed!"
        exit 1
    }
    
    # Build theme
    Write-Info "Building theme..."
    & npm run build
    & npx keycloakify build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Theme build had issues, continuing..."
    } else {
        Write-Info "Theme built successfully"
    }
}

# ==================== Setup Environment ====================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Step "Setting up environment..."
Write-Host "--------------------------------------------" -ForegroundColor Cyan

Set-Location $INFRA_DIR

# Create providers directory
$providersDir = "$ROOT_DIR\kc-server\providers"
if (-not (Test-Path $providersDir)) {
    New-Item -ItemType Directory -Path $providersDir -Force | Out-Null
}

# Copy plugin JAR to providers
Write-Info "Copying plugin JAR..."
$pluginJar = Get-ChildItem "$ROOT_DIR\kc-plugins\build\libs\*-all.jar" -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $pluginJar) {
    $pluginJar = Get-ChildItem "$ROOT_DIR\kc-plugins\build\libs\*.jar" -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch "sources|javadoc" } | Select-Object -First 1
}
if ($pluginJar) {
    Copy-Item $pluginJar.FullName "$providersDir\finappkc-plugins.jar" -Force
    Write-Host "  -> Copied $($pluginJar.Name)" -ForegroundColor Gray
}

# Copy login theme
Write-Info "Deploying login theme..."
$themeCachePaths = @(
    "$ROOT_DIR\kc-themes\node_modules\.cache\keycloakify\maven\keycloak-theme-for-kc-22-to-25\target\classes\theme\finappkc",
    "$ROOT_DIR\kc-themes\node_modules\.cache\keycloakify\maven\keycloak-theme-for-kc-all-other-versions\target\classes\theme\finappkc"
)

$themeCache = $themeCachePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($themeCache) {
    $themeDest = "$ROOT_DIR\kc-server\themes\finappkc"
    
    # Remove old theme
    if (Test-Path $themeDest) {
        Remove-Item $themeDest -Recurse -Force
    }
    
    # Copy entire theme folder
    Copy-Item $themeCache -Destination $themeDest -Recurse -Force
    Write-Host "  -> Theme deployed" -ForegroundColor Gray
} else {
    Write-Warn "Theme cache not found. Run build first."
}

# ==================== Determine Profiles ====================
$profiles = @()

if ($Full) {
    $profiles = @("mail", "monitoring", "observability")
} else {
    if ($WithMail) { $profiles += "mail" }
    if ($WithMonitoring) { $profiles += "monitoring" }
    if ($WithObservability) { $profiles += "observability" }
}

$profileArgs = ""
foreach ($profile in $profiles) {
    $profileArgs += " --profile $profile"
}

# ==================== Start Docker Compose ====================
Write-Host ""
Write-Host "--------------------------------------------" -ForegroundColor Cyan
Write-Step "Starting Docker Compose..."
Write-Host "--------------------------------------------" -ForegroundColor Cyan

# Stop existing containers
Write-Info "Stopping existing containers..."
$env:COMPOSE_IGNORE_WARNINGS = "true"
cmd /c "docker-compose --profile mail --profile monitoring --profile observability down 2>nul"

# Start services
if ($profiles.Count -gt 0) {
    Write-Info "Starting services with profiles: $($profiles -join ', ')..."
    $cmd = "docker-compose$profileArgs up -d"
} else {
    Write-Info "Starting core services (Keycloak + PostgreSQL)..."
    $cmd = "docker-compose up -d"
}
cmd /c $cmd

if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker Compose failed!"
    exit 1
}

# ==================== Wait for Keycloak ====================
Write-Host ""
Write-Info "Waiting for Keycloak to be ready..."
Write-Host "This may take 1-2 minutes on first start..." -ForegroundColor Gray

$maxAttempts = 60
$attempt = 0
$ready = $false

while (-not $ready -and $attempt -lt $maxAttempts) {
    $attempt++
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:9001/health/ready" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $ready = $true
        }
    } catch {
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 3
    }
}

Write-Host ""

if ($ready) {
    # ==================== Post-Init Realm Configuration ====================
    Write-Host ""
    Write-Step "Running realm post-initialization..."
    
    $initScript = Join-Path $ROOT_DIR "realm-config\init-realm.ps1"
    if (Test-Path $initScript) {
        $initParams = @{
            KcUrl = "http://localhost:8080"
            AdminUser = "admin"
            AdminPassword = "admin"
            CreateTestUser = $true
        }
        
        # Pass Google credentials from .env if available
        $envFile = Join-Path $INFRA_DIR ".env"
        if (Test-Path $envFile) {
            Get-Content $envFile | ForEach-Object {
                if ($_ -match "^GOOGLE_CLIENT_ID=(.+)$") { $initParams.GoogleClientId = $matches[1] }
                if ($_ -match "^GOOGLE_CLIENT_SECRET=(.+)$") { $initParams.GoogleClientSecret = $matches[1] }
            }
        }
        
        & $initScript @initParams
    }
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  FinAppKC is ready!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  KEYCLOAK" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor Gray
    Write-Host "  Admin Console:    " -NoNewline; Write-Host "http://localhost:8080/admin" -ForegroundColor Cyan
    Write-Host "  Account Console:  " -NoNewline; Write-Host "http://localhost:8080/realms/finapp/account" -ForegroundColor Cyan
    Write-Host "  Login:            " -NoNewline; Write-Host "http://localhost:8080/realms/finapp/account" -ForegroundColor Cyan
    Write-Host "  Credentials:      " -NoNewline; Write-Host "admin / admin" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Health:           " -NoNewline; Write-Host "http://localhost:9001/health" -ForegroundColor Gray
    Write-Host "  Metrics:          " -NoNewline; Write-Host "http://localhost:9001/metrics" -ForegroundColor Gray
    Write-Host ""
    
    if ($profiles -contains "mail" -or $Full) {
        Write-Host "  MAILHOG (Email Testing)" -ForegroundColor White
        Write-Host "  -----------------------------------------" -ForegroundColor Gray
        Write-Host "  Web UI:           " -NoNewline; Write-Host "http://localhost:8025" -ForegroundColor Cyan
        Write-Host "  SMTP:             " -NoNewline; Write-Host "localhost:1025" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($profiles -contains "monitoring" -or $Full) {
        Write-Host "  MONITORING" -ForegroundColor White
        Write-Host "  -----------------------------------------" -ForegroundColor Gray
        Write-Host "  Grafana:          " -NoNewline; Write-Host "http://localhost:3000" -ForegroundColor Cyan
        Write-Host "                    admin / admin" -ForegroundColor Gray
        Write-Host "  Prometheus:       " -NoNewline; Write-Host "http://localhost:9090" -ForegroundColor Gray
        Write-Host "  Loki:             " -NoNewline; Write-Host "http://localhost:3100" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($profiles -contains "observability" -or $Full) {
        Write-Host "  OBSERVABILITY (Tracing)" -ForegroundColor White
        Write-Host "  -----------------------------------------" -ForegroundColor Gray
        Write-Host "  Jaeger UI:        " -NoNewline; Write-Host "http://localhost:16686" -ForegroundColor Cyan
        Write-Host ""
    }
    
    Write-Host "  WEBAPP" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor Gray
    Write-Host "  To start:         " -NoNewline; Write-Host "cd webapp && npm install && npm run dev" -ForegroundColor Yellow
    Write-Host "  URL:              " -NoNewline; Write-Host "http://localhost:5173" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "  COMMANDS" -ForegroundColor White
    Write-Host "  -----------------------------------------" -ForegroundColor Gray
    Write-Host "  Logs:             " -NoNewline; Write-Host ".\start.ps1 -Logs" -ForegroundColor Gray
    Write-Host "  Status:           " -NoNewline; Write-Host ".\start.ps1 -Status" -ForegroundColor Gray
    Write-Host "  Stop:             " -NoNewline; Write-Host ".\start.ps1 -Stop" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Err "Keycloak failed to start within timeout!"
    Write-Host ""
    Write-Host "Check logs: docker-compose logs keycloak" -ForegroundColor Yellow
    exit 1
}

Set-Location $ROOT_DIR

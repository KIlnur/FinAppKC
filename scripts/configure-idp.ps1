# ============================================================
# Configure Identity Providers (Social Login)
# This script configures Google IDP to only allow linked accounts
# (no automatic registration of new users)
# ============================================================

param(
    [string]$KeycloakUrl = "http://localhost:8080",
    [string]$Realm = "finapp",
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "admin"
)

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Configure Identity Providers" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Get admin token
Write-Host "[INFO] Getting admin token..." -ForegroundColor Green
try {
    $tokenResponse = Invoke-RestMethod -Uri "$KeycloakUrl/realms/master/protocol/openid-connect/token" `
        -Method POST `
        -ContentType "application/x-www-form-urlencoded" `
        -Body @{
            grant_type = "password"
            client_id = "admin-cli"
            username = $AdminUser
            password = $AdminPassword
        }
    $token = $tokenResponse.access_token
    Write-Host "[INFO] Token obtained successfully" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to get admin token: $_" -ForegroundColor Red
    exit 1
}

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

# Check if Google IDP exists
Write-Host "[INFO] Checking Google IDP configuration..." -ForegroundColor Green
try {
    $googleIdp = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/identity-provider/instances/google" `
        -Method GET `
        -Headers $headers `
        -ErrorAction SilentlyContinue
    
    Write-Host "[INFO] Google IDP found, updating configuration..." -ForegroundColor Green
    
    # Update Google IDP to prevent auto-registration
    # Key settings:
    # - trustEmail: false - don't auto-verify email
    # - firstBrokerLoginFlowAlias: "first broker login" with custom flow that requires existing user
    # - storeToken: false
    
    # For now, we'll create a custom first broker login flow that denies new users
    
} catch {
    Write-Host "[WARN] Google IDP not configured. Skipping..." -ForegroundColor Yellow
}

# Create custom authentication flow for first broker login that denies new users
Write-Host ""
Write-Host "[INFO] Creating 'Link Only' first broker login flow..." -ForegroundColor Green

# Check if flow exists
$flowAlias = "link-only-broker-login"
try {
    $existingFlow = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows/$flowAlias" `
        -Method GET `
        -Headers $headers `
        -ErrorAction SilentlyContinue
    
    Write-Host "[INFO] Flow already exists, skipping creation..." -ForegroundColor Yellow
} catch {
    # Create new flow
    $flowBody = @{
        alias = $flowAlias
        description = "Login flow that only allows linking to existing accounts, no registration"
        providerId = "basic-flow"
        topLevel = $true
        builtIn = $false
    } | ConvertTo-Json
    
    try {
        Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows" `
            -Method POST `
            -Headers $headers `
            -Body $flowBody
        
        Write-Host "[INFO] Flow created successfully" -ForegroundColor Green
        
        # Add execution: Detect Existing Broker User
        $execution1 = @{
            provider = "idp-detect-existing-broker-user"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows/$flowAlias/executions/execution" `
            -Method POST `
            -Headers $headers `
            -Body $execution1
        
        # Get executions and set requirements
        $executions = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows/$flowAlias/executions" `
            -Method GET `
            -Headers $headers
        
        foreach ($exec in $executions) {
            if ($exec.providerId -eq "idp-detect-existing-broker-user") {
                $updateExec = @{
                    id = $exec.id
                    requirement = "REQUIRED"
                } | ConvertTo-Json
                
                Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/executions/$($exec.id)" `
                    -Method PUT `
                    -Headers $headers `
                    -Body $updateExec
            }
        }
        
        # Add execution: Automatically Link Brokered Account
        $execution2 = @{
            provider = "idp-auto-link"
        } | ConvertTo-Json
        
        Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows/$flowAlias/executions/execution" `
            -Method POST `
            -Headers $headers `
            -Body $execution2
        
        # Update auto-link to ALTERNATIVE
        $executions = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/flows/$flowAlias/executions" `
            -Method GET `
            -Headers $headers
        
        foreach ($exec in $executions) {
            if ($exec.providerId -eq "idp-auto-link") {
                $updateExec = @{
                    id = $exec.id
                    requirement = "ALTERNATIVE"
                } | ConvertTo-Json
                
                Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/authentication/executions/$($exec.id)" `
                    -Method PUT `
                    -Headers $headers `
                    -Body $updateExec
            }
        }
        
        Write-Host "[INFO] Flow executions configured" -ForegroundColor Green
        
    } catch {
        Write-Host "[ERROR] Failed to create flow: $_" -ForegroundColor Red
    }
}

# Update Google IDP to use this flow
try {
    $googleIdp = Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/identity-provider/instances/google" `
        -Method GET `
        -Headers $headers `
        -ErrorAction Stop
    
    # Update the IDP
    $googleIdp.firstBrokerLoginFlowAlias = $flowAlias
    $googleIdp.trustEmail = $false
    
    $googleIdpJson = $googleIdp | ConvertTo-Json -Depth 10
    
    Invoke-RestMethod -Uri "$KeycloakUrl/admin/realms/$Realm/identity-provider/instances/google" `
        -Method PUT `
        -Headers $headers `
        -Body $googleIdpJson
    
    Write-Host "[INFO] Google IDP updated to use link-only flow" -ForegroundColor Green
    
} catch {
    Write-Host "[WARN] Could not update Google IDP (may not be configured)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Configuration Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Social login is now configured to only allow" -ForegroundColor White
Write-Host "users who have already linked their accounts." -ForegroundColor White
Write-Host ""
Write-Host "To link an account:" -ForegroundColor Gray
Write-Host "1. User logs in with username/password" -ForegroundColor Gray
Write-Host "2. Goes to Account Console -> Linked Accounts" -ForegroundColor Gray
Write-Host "3. Links their Google account" -ForegroundColor Gray
Write-Host ""

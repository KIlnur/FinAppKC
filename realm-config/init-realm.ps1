<#
.SYNOPSIS
  Post-import realm initialization for FinAppKC.
  Run this AFTER Keycloak starts and imports realm-export.json.
  
.DESCRIPTION
  Creates resources that cannot be reliably expressed in realm-export.json:
  - Custom client scope with protocol mappers
  - Custom authentication flows (browser-with-passkey)
  - Google Identity Provider
  - Assigns custom scope to finapp-web client
  - Creates test admin user (dev only)
  
.PARAMETER KcUrl
  Keycloak base URL (default: http://localhost:8080)
.PARAMETER AdminUser
  Admin username (default: admin)
.PARAMETER AdminPassword
  Admin password (default: admin)
.PARAMETER GoogleClientId
  Google OAuth client ID
.PARAMETER GoogleClientSecret
  Google OAuth client secret
.PARAMETER CreateTestUser
  Create test sgadmin user (default: true)
#>
param(
  [string]$KcUrl = "http://localhost:8080",
  [string]$AdminUser = "admin",
  [string]$AdminPassword = "admin",
  [string]$GoogleClientId = "",
  [string]$GoogleClientSecret = "",
  [bool]$CreateTestUser = $true
)

$ErrorActionPreference = "Stop"

function Get-AdminToken {
  $resp = Invoke-RestMethod -Uri "$KcUrl/realms/master/protocol/openid-connect/token" -Method Post -Body @{
    grant_type = "password"
    client_id  = "admin-cli"
    username   = $AdminUser
    password   = $AdminPassword
  }
  return $resp.access_token
}

function Invoke-KcApi {
  param([string]$Path, [string]$Method = "GET", $Body = $null)
  $headers = @{Authorization = "Bearer $(Get-AdminToken)"; "Content-Type" = "application/json"}
  $params = @{Uri = "$KcUrl/admin/realms/finapp$Path"; Method = $Method; Headers = $headers}
  if ($Body) { $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 5 } }
  return Invoke-RestMethod @params
}

Write-Host "`n=== FinAppKC Realm Post-Init ===" -ForegroundColor Cyan

# ── 1. Custom client scope ──
Write-Host "`n[1/6] Creating finapp-user-attributes scope..." -ForegroundColor Yellow
$scopes = Invoke-KcApi "/client-scopes"
$existing = $scopes | Where-Object { $_.name -eq "finapp-user-attributes" }
if (-not $existing) {
  Invoke-KcApi "/client-scopes" -Method Post -Body @{
    name        = "finapp-user-attributes"
    description = "FinApp user attributes in token claims"
    protocol    = "openid-connect"
    attributes  = @{ "include.in.token.scope" = "true"; "display.on.consent.screen" = "false" }
  }
  
  $scopes = Invoke-KcApi "/client-scopes"
  $scopeId = ($scopes | Where-Object { $_.name -eq "finapp-user-attributes" }).id
  
  $mappers = @(
    @{name="phone"; protocolMapper="oidc-usermodel-attribute-mapper"; protocol="openid-connect"; consentRequired=$false; config=@{"userinfo.token.claim"="true";"user.attribute"="phone";"id.token.claim"="true";"access.token.claim"="true";"claim.name"="phone";"jsonType.label"="String"}}
    @{name="department"; protocolMapper="oidc-usermodel-attribute-mapper"; protocol="openid-connect"; consentRequired=$false; config=@{"userinfo.token.claim"="true";"user.attribute"="department";"id.token.claim"="true";"access.token.claim"="true";"claim.name"="department";"jsonType.label"="String"}}
    @{name="employee_id"; protocolMapper="oidc-usermodel-attribute-mapper"; protocol="openid-connect"; consentRequired=$false; config=@{"userinfo.token.claim"="true";"user.attribute"="employee_id";"id.token.claim"="true";"access.token.claim"="true";"claim.name"="employee_id";"jsonType.label"="String"}}
    @{name="merchant_id"; protocolMapper="oidc-usermodel-attribute-mapper"; protocol="openid-connect"; consentRequired=$false; config=@{"userinfo.token.claim"="true";"user.attribute"="merchant_id";"id.token.claim"="true";"access.token.claim"="true";"claim.name"="merchant_id";"jsonType.label"="String"}}
    @{name="groups"; protocolMapper="oidc-group-membership-mapper"; protocol="openid-connect"; consentRequired=$false; config=@{"full.path"="false";"userinfo.token.claim"="true";"id.token.claim"="true";"access.token.claim"="true";"claim.name"="groups";"multivalued"="true"}}
  )
  foreach ($m in $mappers) {
    Invoke-KcApi "/client-scopes/$scopeId/protocol-mappers/models" -Method Post -Body $m
    Write-Host "  + mapper: $($m.name)" -ForegroundColor Gray
  }
  Write-Host "  Created with 5 mappers" -ForegroundColor Green
} else {
  Write-Host "  Already exists, skipping" -ForegroundColor Gray
}

# ── 2. Assign scope to finapp-web client ──
Write-Host "`n[2/6] Assigning scope to finapp-web..." -ForegroundColor Yellow
$clients = Invoke-KcApi "/clients"
$webClient = $clients | Where-Object { $_.clientId -eq "finapp-web" }
if ($webClient) {
  $scopes = Invoke-KcApi "/client-scopes"
  $customScope = $scopes | Where-Object { $_.name -eq "finapp-user-attributes" }
  if ($customScope) {
    try {
      Invoke-WebRequest -Uri "$KcUrl/admin/realms/finapp/clients/$($webClient.id)/default-client-scopes/$($customScope.id)" -Method Put -Headers @{Authorization = "Bearer $(Get-AdminToken)"} -UseBasicParsing | Out-Null
      Write-Host "  Assigned finapp-user-attributes to finapp-web" -ForegroundColor Green
    } catch {
      Write-Host "  Already assigned" -ForegroundColor Gray
    }
  }
}

# ── 3. Authentication flows ──
Write-Host "`n[3/6] Creating authentication flows..." -ForegroundColor Yellow
$flows = Invoke-KcApi "/authentication/flows"
$hasPasskey = $flows | Where-Object { $_.alias -eq "browser-with-passkey" }
if (-not $hasPasskey) {
  # Main flow
  Invoke-KcApi "/authentication/flows" -Method Post -Body '{"alias":"browser-with-passkey","description":"Browser flow with Passkey support","providerId":"basic-flow","builtIn":false,"topLevel":true}'
  
  # Executions
  Invoke-KcApi "/authentication/flows/browser-with-passkey/executions/execution" -Method Post -Body '{"provider":"webauthn-authenticator-passwordless"}'
  Invoke-KcApi "/authentication/flows/browser-with-passkey/executions/execution" -Method Post -Body '{"provider":"auth-cookie"}'
  Invoke-KcApi "/authentication/flows/browser-with-passkey/executions/execution" -Method Post -Body '{"provider":"identity-provider-redirector"}'
  Invoke-KcApi "/authentication/flows/browser-with-passkey/executions/flow" -Method Post -Body '{"alias":"browser-with-passkey forms","description":"Username/password with OTP","type":"basic-flow"}'
  
  # Set all top-level to ALTERNATIVE
  $execs = Invoke-KcApi "/authentication/flows/browser-with-passkey/executions"
  foreach ($e in $execs) {
    if ($e.requirement -ne "ALTERNATIVE") {
      $e.requirement = "ALTERNATIVE"
      Invoke-KcApi "/authentication/flows/browser-with-passkey/executions" -Method Put -Body ($e | ConvertTo-Json -Depth 3)
    }
  }
  
  # Forms sub-flow
  Invoke-KcApi "/authentication/flows/browser-with-passkey%20forms/executions/execution" -Method Post -Body '{"provider":"auth-username-password-form"}'
  Invoke-KcApi "/authentication/flows/browser-with-passkey%20forms/executions/flow" -Method Post -Body '{"alias":"browser-with-passkey Conditional OTP","description":"Conditional OTP","type":"basic-flow"}'
  
  # Set Conditional OTP
  $formsExecs = Invoke-KcApi "/authentication/flows/browser-with-passkey%20forms/executions"
  foreach ($e in $formsExecs) {
    if ($e.displayName -eq "browser-with-passkey Conditional OTP") {
      $e.requirement = "CONDITIONAL"
      Invoke-KcApi "/authentication/flows/browser-with-passkey%20forms/executions" -Method Put -Body ($e | ConvertTo-Json -Depth 3)
    }
  }
  
  # OTP sub-flow
  Invoke-KcApi "/authentication/flows/browser-with-passkey%20Conditional%20OTP/executions/execution" -Method Post -Body '{"provider":"conditional-user-configured"}'
  Invoke-KcApi "/authentication/flows/browser-with-passkey%20Conditional%20OTP/executions/execution" -Method Post -Body '{"provider":"auth-otp-form"}'
  
  # Fix REQUIRED for OTP items
  $allExecs = Invoke-KcApi "/authentication/flows/browser-with-passkey/executions"
  foreach ($e in $allExecs) {
    if (($e.providerId -eq "conditional-user-configured" -or $e.providerId -eq "auth-otp-form") -and $e.requirement -ne "REQUIRED") {
      $e.requirement = "REQUIRED"
      Invoke-KcApi "/authentication/flows/browser-with-passkey/executions" -Method Put -Body ($e | ConvertTo-Json -Depth 3)
    }
  }
  
  # Set as browser flow
  Invoke-KcApi "" -Method Put -Body '{"browserFlow":"browser-with-passkey"}'
  Write-Host "  Created browser-with-passkey flow" -ForegroundColor Green
} else {
  Write-Host "  Already exists, skipping" -ForegroundColor Gray
}

# link-only-broker-login
$hasLinkOnly = $flows | Where-Object { $_.alias -eq "link-only-broker-login" }
if (-not $hasLinkOnly) {
  Invoke-KcApi "/authentication/flows" -Method Post -Body '{"alias":"link-only-broker-login","description":"First broker login - link only (no registration)","providerId":"basic-flow","builtIn":false,"topLevel":true}'
  Write-Host "  Created link-only-broker-login flow" -ForegroundColor Green
} else {
  Write-Host "  link-only-broker-login already exists" -ForegroundColor Gray
}

# ── 4. Google IDP ──
Write-Host "`n[4/6] Configuring Google Identity Provider..." -ForegroundColor Yellow
if ($GoogleClientId -and $GoogleClientSecret) {
  $idps = Invoke-KcApi "/identity-provider/instances"
  $hasGoogle = $idps | Where-Object { $_.alias -eq "google" }
  if (-not $hasGoogle) {
    Invoke-KcApi "/identity-provider/instances" -Method Post -Body @{
      alias       = "google"
      displayName = "Google"
      providerId  = "google"
      enabled     = $true
      trustEmail  = $false
      storeToken  = $false
      linkOnly    = $false
      hideOnLogin = $false
      firstBrokerLoginFlowAlias = "link-only-broker-login"
      config = @{
        syncMode     = "IMPORT"
        clientId     = $GoogleClientId
        clientSecret = $GoogleClientSecret
        defaultScope = "openid email profile"
      }
    }
    Write-Host "  Created Google IDP" -ForegroundColor Green
  } else {
    Write-Host "  Already exists, skipping" -ForegroundColor Gray
  }
} else {
  Write-Host "  Skipped (no GOOGLE_CLIENT_ID/SECRET provided)" -ForegroundColor DarkYellow
}

# ── 5. Test user ──
Write-Host "`n[5/6] Creating test user..." -ForegroundColor Yellow
if ($CreateTestUser) {
  $users = Invoke-KcApi "/users?username=sgadmin"
  if ($users.Count -eq 0) {
    Invoke-KcApi "/users" -Method Post -Body @{
      username      = "sgadmin"
      email         = "ilnur.kutlubaev@yandx.ru"
      firstName     = "Ilnur"
      lastName      = "Kutlubaev"
      enabled       = $true
      emailVerified = $true
      credentials   = @(@{type = "password"; value = "Admin123!"; temporary = $false})
      groups        = @("Administrators")
    }
    
    $users = Invoke-KcApi "/users?username=sgadmin"
    $userId = $users[0].id
    $adminRole = Invoke-KcApi "/roles/admin"
    Invoke-KcApi "/users/$userId/role-mappings/realm" -Method Post -Body "[$($adminRole | ConvertTo-Json)]"
    Write-Host "  Created sgadmin (admin) with password Admin123!" -ForegroundColor Green
  } else {
    Write-Host "  User sgadmin already exists" -ForegroundColor Gray
  }
} else {
  Write-Host "  Skipped" -ForegroundColor Gray
}

# ── 6. Verification ──
Write-Host "`n[6/6] Verification..." -ForegroundColor Yellow
$realm = Invoke-KcApi ""
Write-Host "  Realm:        $($realm.realm)" -ForegroundColor White
Write-Host "  Browser Flow: $($realm.browserFlow)" -ForegroundColor White
Write-Host "  Login Theme:  $($realm.loginTheme)" -ForegroundColor White
Write-Host "  SMTP:         $($realm.smtpServer.host):$($realm.smtpServer.port)" -ForegroundColor White

Write-Host "`n=== Realm initialization complete ===" -ForegroundColor Cyan

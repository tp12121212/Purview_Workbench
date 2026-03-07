param(
  [Parameter(Position = 0)]
  [ValidateSet('full','validate')]
  [string]$Mode = 'full'
)

$ErrorActionPreference = 'Stop'
$script:EntraPermissionCount = 0
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $Root '.setup'
$StateFile = Join-Path $StateDir 'state.psd1'
if (!(Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir | Out-Null }

function Write-Log([string]$Message) { Write-Host "[setup] $Message" }
function Write-Warn([string]$Message) { Write-Warning $Message }
function Get-State {
  if (Test-Path $StateFile) { return Import-PowerShellDataFile $StateFile }
  return @{}
}
function Save-State($state) {
@"
@{
  PNPM_LOCK_HASH = '$($state.PNPM_LOCK_HASH)'
  PY_API_HASH = '$($state.PY_API_HASH)'
  PY_WORKER_HASH = '$($state.PY_WORKER_HASH)'
}
"@ | Set-Content -Path $StateFile -Encoding UTF8
}

function Get-FileHashString([string]$Path) {
  return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash
}

function Find-Python312 {
  foreach ($candidate in @('py -3.13','py -3.12','python','python3')) {
    try {
      $ver = if ($candidate.StartsWith('py ')) {
        & py ($candidate.Split(' ')[1]) -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
      } else {
        & $candidate -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
      }
      if ($LASTEXITCODE -eq 0 -and [version]$ver -ge [version]'3.12') { return $candidate }
    } catch { }
  }
  return $null
}

function Ensure-Prereqs {
  if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js 20+ is required. Install from https://nodejs.org/en/download and rerun.'
  }

  if (!(Get-Command pnpm -ErrorAction SilentlyContinue)) {
    if (Get-Command corepack -ErrorAction SilentlyContinue) {
      corepack enable
      corepack prepare pnpm@9.12.0 --activate
    } else {
      npm install -g pnpm@9.12.0
    }
  }

  $script:PythonBin = Find-Python312
  if (-not $script:PythonBin) {
    throw 'Python 3.12+ is required. Install from https://www.python.org/downloads/windows/ and rerun.'
  }
  Write-Log "Using Python: $script:PythonBin"
}

function Invoke-Python([string]$Command) {
  if ($script:PythonBin.StartsWith('py ')) {
    & py ($script:PythonBin.Split(' ')[1]) $Command
  } else {
    & $script:PythonBin $Command
  }
}

function Ensure-Venv {
  $venv = Join-Path $Root '.venv'
  if (!(Test-Path $venv)) {
    Write-Log 'Creating .venv'
    if ($script:PythonBin.StartsWith('py ')) {
      & py ($script:PythonBin.Split(' ')[1]) -m venv (Join-Path $Root '.venv')
    } else {
      & $script:PythonBin -m venv (Join-Path $Root '.venv')
    }
  } else {
    Write-Log '.venv already exists; reusing'
  }
}

function Ensure-PythonDeps {
  $state = Get-State
  $apiHash = Get-FileHashString (Join-Path $Root 'apps/api/pyproject.toml')
  $workerHash = Get-FileHashString (Join-Path $Root 'apps/worker/pyproject.toml')
  if ($state.PY_API_HASH -eq $apiHash -and $state.PY_WORKER_HASH -eq $workerHash) {
    Write-Log 'Python dependency manifests unchanged; skipping install'
    return
  }

  & (Join-Path $Root '.venv/Scripts/python.exe') -m pip install --upgrade pip
  & (Join-Path $Root '.venv/Scripts/pip.exe') install -e (Join-Path $Root 'apps/api') -e (Join-Path $Root 'apps/worker') pytest

  $state.PY_API_HASH = $apiHash
  $state.PY_WORKER_HASH = $workerHash
  Save-State $state
}

function Ensure-JSDeps {
  $state = Get-State
  $lockHash = Get-FileHashString (Join-Path $Root 'pnpm-lock.yaml')
  if ($state.PNPM_LOCK_HASH -eq $lockHash -and (Test-Path (Join-Path $Root 'node_modules'))) {
    Write-Log 'pnpm lock unchanged; skipping install'
    return
  }
  Push-Location $Root
  pnpm install
  Pop-Location
  $state.PNPM_LOCK_HASH = $lockHash
  Save-State $state
}

function Read-EnvValue([string]$Path, [string]$Key) {
  if (!(Test-Path $Path)) { return '' }
  $line = Get-Content $Path | Where-Object { $_ -match "^$Key=" } | Select-Object -First 1
  if (-not $line) { return '' }
  return ($line -split '=',2)[1]
}

function Prompt-Env([string]$Key, [string]$Current, [string]$Help, [string]$Default, [bool]$Required = $false) {
  if ($Current) {
    Write-Log "$Key already set; preserving existing value from .env"
    return $Current
  }
  if ($Default) {
    Write-Log "$Key missing; using default value: $Default"
    return $Default
  }

  while ($true) {
    Write-Host "`nRequired configuration: $Key"
    Write-Host "Help: $Help"
    if ($Required) {
      Write-Host 'This value has no safe default and is required to continue.'
    }
    $in = Read-Host "$Key value (required, no default)"
    if ($in) { return $in }
    Write-Warn "No value entered for $Key. Please provide a non-empty value."
  }
}

function Write-EnvFiles {
  $rootEnv = Join-Path $Root '.env'

  Write-Host "`nEnvironment configuration (non-Entra values first)"
  Write-Host '  Entra app registration selection/validation happens in the next step.'

  $VITE_ENTRA_CLIENT_ID = Read-EnvValue $rootEnv 'VITE_ENTRA_CLIENT_ID'
  $VITE_ENTRA_AUTHORITY = Read-EnvValue $rootEnv 'VITE_ENTRA_AUTHORITY'
  $VITE_ENTRA_REDIRECT_URI = Read-EnvValue $rootEnv 'VITE_ENTRA_REDIRECT_URI'
  $VITE_API_AUDIENCE = Read-EnvValue $rootEnv 'VITE_API_AUDIENCE'
  $API_ENTRA_CLIENT_ID = Read-EnvValue $rootEnv 'API_ENTRA_CLIENT_ID'
  $API_ALLOWED_AUDIENCE = Read-EnvValue $rootEnv 'API_ALLOWED_AUDIENCE'
  $API_ADMIN_CONSENT_REDIRECT_URI = Read-EnvValue $rootEnv 'API_ADMIN_CONSENT_REDIRECT_URI'

  if (-not $VITE_ENTRA_AUTHORITY) { $VITE_ENTRA_AUTHORITY = 'https://login.microsoftonline.com/common' }
  if (-not $VITE_ENTRA_REDIRECT_URI) { $VITE_ENTRA_REDIRECT_URI = 'http://localhost:5173' }
  if (-not $VITE_API_AUDIENCE) { $VITE_API_AUDIENCE = 'api://purview-workbench' }
  if (-not $API_ADMIN_CONSENT_REDIRECT_URI) { $API_ADMIN_CONSENT_REDIRECT_URI = 'http://localhost:5173/auth/consent-complete' }

  $VITE_API_BASE_URL = Prompt-Env 'VITE_API_BASE_URL' (Read-EnvValue $rootEnv 'VITE_API_BASE_URL') 'Base URL for local API used by the web app.' 'http://localhost:8000'

  $API_ENTRA_TENANT_MODE = Prompt-Env 'API_ENTRA_TENANT_MODE' (Read-EnvValue $rootEnv 'API_ENTRA_TENANT_MODE') 'Tenant mode from architecture. Keep as multi-tenant unless intentionally changing design.' 'multi-tenant'
  $API_DATABASE_URL = Prompt-Env 'API_DATABASE_URL' (Read-EnvValue $rootEnv 'API_DATABASE_URL') 'SQLAlchemy DB URL. SQLite default is suitable for local development.' 'sqlite:///./purview_workbench.db'

@"
VITE_ENTRA_CLIENT_ID=$VITE_ENTRA_CLIENT_ID
VITE_ENTRA_AUTHORITY=$VITE_ENTRA_AUTHORITY
VITE_ENTRA_REDIRECT_URI=$VITE_ENTRA_REDIRECT_URI
VITE_API_AUDIENCE=$VITE_API_AUDIENCE
VITE_API_BASE_URL=$VITE_API_BASE_URL
API_ENTRA_CLIENT_ID=$API_ENTRA_CLIENT_ID
API_ENTRA_TENANT_MODE=$API_ENTRA_TENANT_MODE
API_ALLOWED_AUDIENCE=$API_ALLOWED_AUDIENCE
API_DATABASE_URL=$API_DATABASE_URL
API_ADMIN_CONSENT_REDIRECT_URI=$API_ADMIN_CONSENT_REDIRECT_URI
"@ | Set-Content -Path $rootEnv -Encoding UTF8

@"
VITE_ENTRA_CLIENT_ID=$VITE_ENTRA_CLIENT_ID
VITE_ENTRA_AUTHORITY=$VITE_ENTRA_AUTHORITY
VITE_ENTRA_REDIRECT_URI=$VITE_ENTRA_REDIRECT_URI
VITE_API_AUDIENCE=$VITE_API_AUDIENCE
VITE_API_BASE_URL=$VITE_API_BASE_URL
"@ | Set-Content -Path (Join-Path $Root 'apps/web/.env.local') -Encoding UTF8

@"
API_ENTRA_CLIENT_ID=$API_ENTRA_CLIENT_ID
API_ENTRA_TENANT_MODE=$API_ENTRA_TENANT_MODE
API_ALLOWED_AUDIENCE=$API_ALLOWED_AUDIENCE
API_DATABASE_URL=$API_DATABASE_URL
API_ADMIN_CONSENT_REDIRECT_URI=$API_ADMIN_CONSENT_REDIRECT_URI
"@ | Set-Content -Path (Join-Path $Root 'apps/api/.env') -Encoding UTF8

  Write-Log 'Wrote .env, apps/web/.env.local, and apps/api/.env'
}

function Import-RootEnv {
  $envPath = Join-Path $Root '.env'
  if (!(Test-Path $envPath)) { throw '.env missing. Run full setup first.' }
  Get-Content $envPath | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
    $parts = $_ -split '=',2
    [Environment]::SetEnvironmentVariable($parts[0], $parts[1])
    Set-Item -Path ("Env:" + $parts[0]) -Value $parts[1]
  }
}

function Validate-Env {
  Import-RootEnv
  if (-not $env:VITE_ENTRA_CLIENT_ID) { throw 'VITE_ENTRA_CLIENT_ID required' }
  if (-not $env:API_ENTRA_CLIENT_ID) { throw 'API_ENTRA_CLIENT_ID required' }
  if ($env:VITE_API_AUDIENCE -ne $env:API_ALLOWED_AUDIENCE) { throw 'VITE_API_AUDIENCE must equal API_ALLOWED_AUDIENCE' }
  if ($env:API_ENTRA_TENANT_MODE -ne 'multi-tenant') { Write-Warn 'API_ENTRA_TENANT_MODE is not multi-tenant' }
  Write-Log 'Environment values validated'
}

function Write-EnvBundle {
@"
VITE_ENTRA_CLIENT_ID=$($env:VITE_ENTRA_CLIENT_ID)
VITE_ENTRA_AUTHORITY=$($env:VITE_ENTRA_AUTHORITY)
VITE_ENTRA_REDIRECT_URI=$($env:VITE_ENTRA_REDIRECT_URI)
VITE_API_AUDIENCE=$($env:VITE_API_AUDIENCE)
VITE_API_BASE_URL=$($env:VITE_API_BASE_URL)
API_ENTRA_CLIENT_ID=$($env:API_ENTRA_CLIENT_ID)
API_ENTRA_TENANT_MODE=$($env:API_ENTRA_TENANT_MODE)
API_ALLOWED_AUDIENCE=$($env:API_ALLOWED_AUDIENCE)
API_DATABASE_URL=$($env:API_DATABASE_URL)
API_ADMIN_CONSENT_REDIRECT_URI=$($env:API_ADMIN_CONSENT_REDIRECT_URI)
"@ | Set-Content -Path (Join-Path $Root '.env') -Encoding UTF8

@"
VITE_ENTRA_CLIENT_ID=$($env:VITE_ENTRA_CLIENT_ID)
VITE_ENTRA_AUTHORITY=$($env:VITE_ENTRA_AUTHORITY)
VITE_ENTRA_REDIRECT_URI=$($env:VITE_ENTRA_REDIRECT_URI)
VITE_API_AUDIENCE=$($env:VITE_API_AUDIENCE)
VITE_API_BASE_URL=$($env:VITE_API_BASE_URL)
"@ | Set-Content -Path (Join-Path $Root 'apps/web/.env.local') -Encoding UTF8

@"
API_ENTRA_CLIENT_ID=$($env:API_ENTRA_CLIENT_ID)
API_ENTRA_TENANT_MODE=$($env:API_ENTRA_TENANT_MODE)
API_ALLOWED_AUDIENCE=$($env:API_ALLOWED_AUDIENCE)
API_DATABASE_URL=$($env:API_DATABASE_URL)
API_ADMIN_CONSENT_REDIRECT_URI=$($env:API_ADMIN_CONSENT_REDIRECT_URI)
"@ | Set-Content -Path (Join-Path $Root 'apps/api/.env') -Encoding UTF8
}

function Require-AzSession {
  if (!(Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Install from https://learn.microsoft.com/cli/azure/install-azure-cli'
  }
  az account show | Out-Null
}

function Ensure-ServicePrincipal([string]$ClientId) {
  try {
    az ad sp show --id $ClientId | Out-Null
  } catch {
    Write-Warn "Service principal missing for $ClientId; creating it now."
    $createOutput = ''
    try {
      $createOutput = az ad sp create --id $ClientId 2>&1 | Out-String
    } catch {
      $createOutput = $_.Exception.Message
    }
    if ($LASTEXITCODE -eq 0) { return }
    if ($createOutput -match 'already in use') {
      Write-Warn "Service principal appears to already exist (Azure CLI returned 'already in use'). Continuing."
      return
    }
    throw "Failed to create service principal for $ClientId. $createOutput"
  }
}

function Validate-EntraRegistration([string]$ClientId) {
  $issues = New-Object System.Collections.Generic.List[string]
  try {
    $app = az ad app show --id $ClientId | ConvertFrom-Json
  } catch {
    $issues.Add("Entra app registration not found for client ID: $ClientId")
    $app = $null
  }

  if ($app) {
    if ($app.signInAudience -ne 'AzureADMultipleOrgs') {
      $issues.Add("signInAudience is '$($app.signInAudience)' (expected AzureADMultipleOrgs)")
    }

    $identifierUri = if ($app.identifierUris.Count -gt 0) { $app.identifierUris[0] } else { '' }
    if (-not $identifierUri) {
      $issues.Add("No identifier URI configured. Expected: $($env:VITE_API_AUDIENCE)")
    } elseif ($identifierUri -ne $env:VITE_API_AUDIENCE) {
      $issues.Add("Identifier URI mismatch. Current: $identifierUri Expected: $($env:VITE_API_AUDIENCE)")
    }

    $requiredRedirects = @($env:VITE_ENTRA_REDIRECT_URI, $env:API_ADMIN_CONSENT_REDIRECT_URI)
    $configuredRedirects = @()
    if ($app.web -and $app.web.redirectUris) { $configuredRedirects = @($app.web.redirectUris) }
    foreach ($redirect in $requiredRedirects) {
      if (-not ($configuredRedirects -contains $redirect)) {
        $issues.Add("Missing required redirect URI: $redirect")
      }
    }
  }

  try { az ad sp show --id $ClientId | Out-Null } catch { $issues.Add("Service principal missing for app: $ClientId") }

  try {
    $permCount = [int](az ad app permission list --id $ClientId --query 'length([])' -o tsv)
    $script:EntraPermissionCount = $permCount
    if ($permCount -eq 0) {
      Write-Warn 'No app permission entries found. Current scaffold uses minimal delegated/dev token flow.'
    }
  } catch {
    $script:EntraPermissionCount = 0
    Write-Warn 'Could not query app permissions. Continue with manual validation if needed.'
  }

  if ($issues.Count -gt 0) {
    foreach ($issue in $issues) { Write-Warning $issue }
    Write-Host 'Remediation commands:'
    Write-Host "  az ad app update --id `"$ClientId`" --sign-in-audience AzureADMultipleOrgs"
    Write-Host "  az ad app update --id `"$ClientId`" --web-redirect-uris `"$($env:VITE_ENTRA_REDIRECT_URI)`" `"$($env:API_ADMIN_CONSENT_REDIRECT_URI)`""
    Write-Host "  az ad app update --id `"$ClientId`" --identifier-uris `"$($env:VITE_API_AUDIENCE)`""
    Write-Host "  az ad sp show --id `"$ClientId`" || az ad sp create --id `"$ClientId`""
    Write-Host "  # If create returns 'already in use', treat that as already existing."
    return $false
  }

  Write-Log "Entra registration validation passed for $ClientId"
  return $true
}

function Confirm-AdminConsent([string]$ClientId, [string]$TenantContext) {
  if ($script:EntraPermissionCount -eq 0) {
    Write-Warn 'Skipping admin consent step because app registration has no configured permission entries.'
    return
  }

  $consentOutput = ''
  try {
    $consentOutput = az ad app permission admin-consent --id $ClientId 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
      Write-Log 'Admin consent granted automatically via Azure CLI.'
      return
    }
  } catch {
    $consentOutput = $_.Exception.Message
  }

  if ($consentOutput -match 'AADSTS1003031|misconfigured') {
    Write-Warn 'Admin consent endpoint returned misconfigured/no-required-permissions error.'
    Write-Warn 'Proceeding because this scaffold currently has no mandatory permission grants.'
    return
  }

  Write-Warn 'Automatic admin consent did not complete.'

  $adminUrl = "https://login.microsoftonline.com/$TenantContext/adminconsent?client_id=$ClientId&redirect_uri=$($env:API_ADMIN_CONSENT_REDIRECT_URI)"
  Write-Host 'Manual admin consent is required before setup can continue.'
  Write-Host '  1) Open this URL in a browser as tenant admin:'
  Write-Host "     $adminUrl"
  Write-Host '  2) Approve consent and wait for redirect to:'
  Write-Host "     $($env:API_ADMIN_CONSENT_REDIRECT_URI)"
  while ($true) {
    $confirmed = Read-Host 'Confirm admin consent is complete [y/N]'
    if ($confirmed -in @('y','Y')) { return }
    Write-Warn 'Admin consent confirmation is required to proceed.'
  }
}

function Setup-Entra {
  Import-RootEnv
  Require-AzSession
  $currentTenantId = ''
  try { $currentTenantId = az account show --query tenantId -o tsv } catch { $currentTenantId = '' }
  $tenantContext = if ($currentTenantId) { $currentTenantId } else { 'common' }

  Write-Host "`nMicrosoft Entra ID app registration is required for this application."
  Write-Host 'Why this is needed:'
  Write-Host '  - Web auth configuration requires an Entra application client ID.'
  Write-Host '  - API token audience/client checks depend on the same app registration.'
  Write-Host '  - Admin consent is required for tenant-scoped protected actions.'
  Write-Host 'This setup step configures and validates the registration before Entra env values are finalized.'

  while ($true) {
    Write-Host "`nMicrosoft Entra app registration flow:"
    Write-Host '  A) use existing app registration'
    Write-Host '     - Enter an existing client ID'
    Write-Host '     - Script validates app existence, multitenant audience, redirect URIs, API audience, and SP'
    Write-Host '  B) create new app registration'
    Write-Host '     - Script creates and configures a new multitenant app via Azure CLI'
    Write-Host '     - Script sets redirect URIs, identifier URI, and service principal'
    $flow = Read-Host 'Choose [A/B] (default A)'
    if (-not $flow) { $flow = 'A' }
    $flow = $flow.ToUpperInvariant()

    if ($flow -eq 'A') {
      while ($true) {
        $tenantInput = Read-Host "Tenant ID for validation/admin-consent URL context [$tenantContext]"
        if ($tenantInput) { $tenantContext = $tenantInput }
        if ($currentTenantId -and $tenantContext -ne 'common' -and $tenantContext -ne $currentTenantId) {
          Write-Warn "Provided tenant ID differs from current Azure CLI tenant ($currentTenantId)."
        }

        $existingId = Read-Host "Existing Entra app client ID [$($env:VITE_ENTRA_CLIENT_ID)]"
        if (-not $existingId) { $existingId = $env:VITE_ENTRA_CLIENT_ID }
        if ($existingId -notmatch '^[0-9a-fA-F-]{32,36}$') {
          Write-Warn 'Client ID format looks invalid. Expected GUID-like value.'
          continue
        }

        $env:VITE_ENTRA_CLIENT_ID = $existingId
        $env:API_ENTRA_CLIENT_ID = $existingId
        if ($env:VITE_API_AUDIENCE -eq 'api://purview-workbench') {
          $env:VITE_API_AUDIENCE = "api://$existingId"
          $env:API_ALLOWED_AUDIENCE = $env:VITE_API_AUDIENCE
          Write-Warn "Updated API audience to match selected app: $($env:VITE_API_AUDIENCE)"
        }

        if (Validate-EntraRegistration -ClientId $existingId) {
          Ensure-ServicePrincipal -ClientId $existingId
          break
        }

        Write-Host "`nValidation failed. Next action:"
        Write-Host '  R) retry existing app values after remediation'
        Write-Host '  S) switch to create-new flow'
        Write-Host '  C) continue after manual fixes (best-effort)'
        Write-Host '  Q) quit setup now'
        $next = Read-Host 'Choose [R/S/C/Q] (default R)'
        if (-not $next) { $next = 'R' }
        $next = $next.ToUpperInvariant()
        if ($next -eq 'S') { $flow = 'B'; break }
        if ($next -eq 'C') { Write-Warn 'Continuing with user-confirmed manual fixes.'; break }
        if ($next -eq 'Q') { throw 'Setup aborted by user.' }
      }
      if ($flow -eq 'B') { continue }
      break
    }

    if ($flow -eq 'B') {
      $tenantInput = Read-Host "Tenant ID for app creation/admin-consent URL context [$tenantContext]"
      if ($tenantInput) { $tenantContext = $tenantInput }
      $appName = Read-Host 'New app registration name [PurviewWorkbench-Local]'
      if (-not $appName) { $appName = 'PurviewWorkbench-Local' }

      Write-Log "Creating new Entra app registration '$appName'"
      $newId = az ad app create --display-name $appName --sign-in-audience AzureADMultipleOrgs --web-redirect-uris $env:VITE_ENTRA_REDIRECT_URI $env:API_ADMIN_CONSENT_REDIRECT_URI --query appId -o tsv
      $env:VITE_ENTRA_CLIENT_ID = $newId
      $env:API_ENTRA_CLIENT_ID = $newId
      $env:VITE_API_AUDIENCE = "api://$newId"
      $env:API_ALLOWED_AUDIENCE = $env:VITE_API_AUDIENCE

      az ad app update --id $newId --sign-in-audience AzureADMultipleOrgs | Out-Null
      az ad app update --id $newId --web-redirect-uris $env:VITE_ENTRA_REDIRECT_URI $env:API_ADMIN_CONSENT_REDIRECT_URI | Out-Null
      az ad app update --id $newId --identifier-uris $env:VITE_API_AUDIENCE | Out-Null
      Ensure-ServicePrincipal -ClientId $newId

      if (-not (Validate-EntraRegistration -ClientId $newId)) {
        throw 'Created app validation failed. Review remediation output and rerun setup.'
      }
      break
    }

    Write-Warn 'Invalid choice. Enter A or B.'
  }

  Confirm-AdminConsent -ClientId $env:VITE_ENTRA_CLIENT_ID -TenantContext $tenantContext
  Write-EnvBundle
  Write-Log 'Updated .env, apps/web/.env.local, and apps/api/.env with validated Entra settings'
}

function Run-Migrations {
  Import-RootEnv
  Push-Location (Join-Path $Root 'apps/api')
  & (Join-Path $Root '.venv/Scripts/alembic.exe') upgrade head
  Pop-Location
  Write-Log 'Alembic migrations succeeded'
}

function Full-Setup {
  Ensure-Prereqs
  Ensure-Venv
  Ensure-PythonDeps
  Ensure-JSDeps
  Write-EnvFiles
  Setup-Entra
  Validate-Env
  Run-Migrations
  Write-Log 'Setup complete.'
}

switch ($Mode) {
  'full' { Full-Setup }
  'validate' { Ensure-Prereqs; Ensure-Venv; Validate-Env; Run-Migrations; Write-Log 'Validation complete' }
}

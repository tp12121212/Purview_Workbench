param(
  [Parameter(Position = 0)]
  [ValidateSet('full','run-api','run-web','run-worker','validate')]
  [string]$Mode = 'full'
)

$ErrorActionPreference = 'Stop'
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

function Prompt-Env([string]$Key, [string]$Current, [string]$Help, [string]$Default) {
  Write-Host "`n$Key"
  Write-Host "  $Help"
  $effective = if ($Current) { $Current } else { $Default }
  $in = Read-Host "Enter value [$effective]"
  if ($in) { return $in }
  return $effective
}

function Write-EnvFiles {
  $rootEnv = Join-Path $Root '.env'

  $VITE_ENTRA_CLIENT_ID = Prompt-Env 'VITE_ENTRA_CLIENT_ID' (Read-EnvValue $rootEnv 'VITE_ENTRA_CLIENT_ID') 'Client/Application ID for Entra app.' ''
  $VITE_ENTRA_AUTHORITY = Prompt-Env 'VITE_ENTRA_AUTHORITY' (Read-EnvValue $rootEnv 'VITE_ENTRA_AUTHORITY') 'Usually https://login.microsoftonline.com/common' 'https://login.microsoftonline.com/common'
  $VITE_ENTRA_REDIRECT_URI = Prompt-Env 'VITE_ENTRA_REDIRECT_URI' (Read-EnvValue $rootEnv 'VITE_ENTRA_REDIRECT_URI') 'Web redirect URI configured in app registration.' 'http://localhost:5173'
  $VITE_API_AUDIENCE = Prompt-Env 'VITE_API_AUDIENCE' (Read-EnvValue $rootEnv 'VITE_API_AUDIENCE') 'API audience, usually api://<client-id>' 'api://purview-workbench'
  $VITE_API_BASE_URL = Prompt-Env 'VITE_API_BASE_URL' (Read-EnvValue $rootEnv 'VITE_API_BASE_URL') 'Local API base URL.' 'http://localhost:8000'

  $API_ENTRA_CLIENT_ID = Prompt-Env 'API_ENTRA_CLIENT_ID' (Read-EnvValue $rootEnv 'API_ENTRA_CLIENT_ID') 'Same app client ID used by API token validation.' $VITE_ENTRA_CLIENT_ID
  $API_ENTRA_TENANT_MODE = Prompt-Env 'API_ENTRA_TENANT_MODE' (Read-EnvValue $rootEnv 'API_ENTRA_TENANT_MODE') 'Keep multi-tenant for current architecture.' 'multi-tenant'
  $API_ALLOWED_AUDIENCE = Prompt-Env 'API_ALLOWED_AUDIENCE' (Read-EnvValue $rootEnv 'API_ALLOWED_AUDIENCE') 'Should match VITE_API_AUDIENCE.' $VITE_API_AUDIENCE
  $API_DATABASE_URL = Prompt-Env 'API_DATABASE_URL' (Read-EnvValue $rootEnv 'API_DATABASE_URL') 'SQLAlchemy URL (default sqlite local file).' 'sqlite:///./purview_workbench.db'
  $API_ADMIN_CONSENT_REDIRECT_URI = Prompt-Env 'API_ADMIN_CONSENT_REDIRECT_URI' (Read-EnvValue $rootEnv 'API_ADMIN_CONSENT_REDIRECT_URI') 'Redirect after admin consent.' 'http://localhost:5173/auth/consent-complete'

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

function Setup-Entra {
  Import-RootEnv
  Write-Host "`nMicrosoft Entra app registration setup mode:"
  Write-Host '  1) use-existing'
  Write-Host '  2) automatic (Azure CLI)'
  Write-Host '  3) manual (show commands)'
  $mode = Read-Host 'Choose [1/2/3] (default 1)'
  if (-not $mode) { $mode = '1' }

  if ($mode -eq '2') {
    if (!(Get-Command az -ErrorAction SilentlyContinue)) { throw 'Azure CLI required for automatic mode.' }
    az account show | Out-Null

    $exists = $true
    try { az ad app show --id $env:VITE_ENTRA_CLIENT_ID | Out-Null } catch { $exists = $false }
    if (-not $exists) {
      $newId = az ad app create --display-name PurviewWorkbench-Local --sign-in-audience AzureADMultipleOrgs --web-redirect-uris $env:VITE_ENTRA_REDIRECT_URI $env:API_ADMIN_CONSENT_REDIRECT_URI --query appId -o tsv
      $env:VITE_ENTRA_CLIENT_ID = $newId
      $env:API_ENTRA_CLIENT_ID = $newId
      $env:VITE_API_AUDIENCE = "api://$newId"
      $env:API_ALLOWED_AUDIENCE = $env:VITE_API_AUDIENCE
      Write-Log "Created app registration $newId"
    }

    az ad app update --id $env:VITE_ENTRA_CLIENT_ID --sign-in-audience AzureADMultipleOrgs | Out-Null
    az ad app update --id $env:VITE_ENTRA_CLIENT_ID --web-redirect-uris $env:VITE_ENTRA_REDIRECT_URI $env:API_ADMIN_CONSENT_REDIRECT_URI | Out-Null
    az ad app update --id $env:VITE_ENTRA_CLIENT_ID --identifier-uris $env:VITE_API_AUDIENCE | Out-Null

    try { az ad sp show --id $env:VITE_ENTRA_CLIENT_ID | Out-Null } catch { az ad sp create --id $env:VITE_ENTRA_CLIENT_ID | Out-Null }
    try { az ad app permission admin-consent --id $env:VITE_ENTRA_CLIENT_ID | Out-Null } catch { Write-Warn 'Automatic admin consent failed. Complete manually.' }
  } elseif ($mode -eq '3') {
    Write-Host @"
Run these commands after az login:
az ad app create --display-name PurviewWorkbench-Local --sign-in-audience AzureADMultipleOrgs --web-redirect-uris "$($env:VITE_ENTRA_REDIRECT_URI)" "$($env:API_ADMIN_CONSENT_REDIRECT_URI)"
az ad app update --id <APP_ID> --identifier-uris "$($env:VITE_API_AUDIENCE)"
az ad sp create --id <APP_ID>
az ad app permission admin-consent --id <APP_ID>
"@
    Read-Host 'Press Enter when manual app setup is complete' | Out-Null
  }

  $adminUrl = "https://login.microsoftonline.com/common/adminconsent?client_id=$($env:VITE_ENTRA_CLIENT_ID)&redirect_uri=$($env:API_ADMIN_CONSENT_REDIRECT_URI)"
  Write-Host "Admin consent URL: $adminUrl"
  $confirmed = Read-Host 'Confirm admin consent has been granted [y/N]'
  if ($confirmed -notin @('y','Y')) { throw 'Admin consent confirmation required.' }
}

function Run-Migrations {
  Import-RootEnv
  Push-Location (Join-Path $Root 'apps/api')
  & (Join-Path $Root '.venv/Scripts/alembic.exe') upgrade head
  Pop-Location
  Write-Log 'Alembic migrations succeeded'
}

function Run-Api { Import-RootEnv; Push-Location $Root; & (Join-Path $Root '.venv/Scripts/python.exe') -m uvicorn src.main:app --reload --app-dir apps/api; Pop-Location }
function Run-Web { Push-Location $Root; pnpm --filter @purview/web dev; Pop-Location }
function Run-Worker { Import-RootEnv; Push-Location $Root; & (Join-Path $Root '.venv/Scripts/python.exe') apps/worker/src/main.py; Pop-Location }

function Full-Setup {
  Ensure-Prereqs
  Ensure-Venv
  Ensure-PythonDeps
  Ensure-JSDeps
  Write-EnvFiles
  Validate-Env
  Setup-Entra
  Run-Migrations
  Write-Log "Setup complete. Use '.\\setup.cmd run-api' and '.\\setup.cmd run-web'."
}

switch ($Mode) {
  'full' { Full-Setup }
  'run-api' { Run-Api }
  'run-web' { Run-Web }
  'run-worker' { Run-Worker }
  'validate' { Ensure-Prereqs; Ensure-Venv; Validate-Env; Run-Migrations; Write-Log 'Validation complete' }
}

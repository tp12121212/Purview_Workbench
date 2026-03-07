#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$ROOT_DIR/.setup"
STATE_FILE="$STATE_DIR/state.env"
mkdir -p "$STATE_DIR"

MODE="${1:-full}"

log() { printf '[setup] %s\n' "$*"; }
warn() { printf '[setup][warn] %s\n' "$*" >&2; }
err() { printf '[setup][error] %s\n' "$*" >&2; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

sha256_file() {
  local file="$1"
  if command_exists sha256sum; then
    sha256sum "$file" | awk '{print $1}'
  else
    shasum -a 256 "$file" | awk '{print $1}'
  fi
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
  fi
}

save_state() {
  cat >"$STATE_FILE" <<STATE
PNPM_LOCK_HASH=${PNPM_LOCK_HASH:-}
PY_API_HASH=${PY_API_HASH:-}
PY_WORKER_HASH=${PY_WORKER_HASH:-}
STATE
}

find_python312() {
  local candidates=(python3.13 python3.12 python3 python)
  local c
  for c in "${candidates[@]}"; do
    if command_exists "$c"; then
      if "$c" - <<'PY' >/dev/null 2>&1
import sys
raise SystemExit(0 if sys.version_info >= (3, 12) else 1)
PY
      then
        echo "$c"
        return 0
      fi
    fi
  done
  return 1
}

install_prerequisites() {
  if ! command_exists node; then
    warn "Node.js is missing. Attempting installation."
    if command_exists brew; then
      brew install node
    elif command_exists apt-get; then
      sudo apt-get update && sudo apt-get install -y nodejs npm
    else
      err "Unable to auto-install Node.js. Install Node.js 20+ and re-run."
      exit 1
    fi
  fi

  if ! command_exists pnpm; then
    warn "pnpm is missing. Attempting installation via corepack."
    if command_exists corepack; then
      corepack enable
      corepack prepare pnpm@9.12.0 --activate
    elif command_exists npm; then
      npm install -g pnpm@9.12.0
    else
      err "Unable to install pnpm. Install pnpm 9.12.0+ and rerun."
      exit 1
    fi
  fi

  if [[ "$(pnpm --version | cut -d. -f1)" -lt 9 ]]; then
    warn "pnpm major version is < 9; upgrading to 9.12.0"
    if command_exists corepack; then
      corepack prepare pnpm@9.12.0 --activate
    else
      npm install -g pnpm@9.12.0
    fi
  fi

  PYTHON_BIN="$(find_python312 || true)"
  if [[ -z "${PYTHON_BIN:-}" ]]; then
    warn "Python 3.12+ not found. Attempting installation."
    if command_exists brew; then
      brew install python@3.12
    elif command_exists apt-get; then
      sudo apt-get update && sudo apt-get install -y python3.12 python3.12-venv
    fi
    PYTHON_BIN="$(find_python312 || true)"
    if [[ -z "$PYTHON_BIN" ]]; then
      err "Python 3.12+ is required. Please install and re-run."
      exit 1
    fi
  fi
  log "Using Python interpreter: $PYTHON_BIN"
}

setup_venv() {
  if [[ ! -d "$ROOT_DIR/.venv" ]]; then
    log "Creating virtual environment at .venv"
    "$PYTHON_BIN" -m venv "$ROOT_DIR/.venv"
  else
    log ".venv already exists; reusing"
  fi
}

install_python_deps_if_needed() {
  load_state
  local api_hash worker_hash
  api_hash="$(sha256_file "$ROOT_DIR/apps/api/pyproject.toml")"
  worker_hash="$(sha256_file "$ROOT_DIR/apps/worker/pyproject.toml")"

  if [[ "${PY_API_HASH:-}" == "$api_hash" && "${PY_WORKER_HASH:-}" == "$worker_hash" ]]; then
    log "Python dependency manifests unchanged; skipping pip install"
    return
  fi

  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv/bin/activate"
  python -m pip install --upgrade pip
  pip install -e "$ROOT_DIR/apps/api" -e "$ROOT_DIR/apps/worker" pytest
  deactivate

  PY_API_HASH="$api_hash"
  PY_WORKER_HASH="$worker_hash"
  save_state
}

install_js_deps_if_needed() {
  load_state
  local lock_hash
  lock_hash="$(sha256_file "$ROOT_DIR/pnpm-lock.yaml")"

  if [[ "${PNPM_LOCK_HASH:-}" == "$lock_hash" && -d "$ROOT_DIR/node_modules" ]]; then
    log "pnpm lock unchanged and node_modules present; skipping pnpm install"
    return
  fi

  (cd "$ROOT_DIR" && pnpm install)
  PNPM_LOCK_HASH="$lock_hash"
  save_state
}

extract_env_value() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

prompt_env_value() {
  local key="$1" current="$2" help="$3" default="$4"
  local effective_default="${current:-$default}"
  echo
  echo "$key"
  echo "  $help"
  read -r -p "Enter value [${effective_default}]: " val
  echo "${val:-$effective_default}"
}

write_env_files() {
  local root_env="$ROOT_DIR/.env"
  local web_env="$ROOT_DIR/apps/web/.env.local"
  local api_env="$ROOT_DIR/apps/api/.env"

  local current_root="$root_env"
  [[ -f "$root_env" ]] || current_root="/dev/null"

  local vite_client_id vite_authority vite_redirect vite_audience vite_api_base
  local api_client_id api_tenant_mode api_audience api_db_url api_consent_redirect

  vite_client_id=$(prompt_env_value "VITE_ENTRA_CLIENT_ID" "$(extract_env_value "$current_root" "VITE_ENTRA_CLIENT_ID")" "Client/Application (app) ID for the Entra app registration used by the web app." "")
  vite_authority=$(prompt_env_value "VITE_ENTRA_AUTHORITY" "$(extract_env_value "$current_root" "VITE_ENTRA_AUTHORITY")" "Authority URL, usually https://login.microsoftonline.com/common for multi-tenant." "https://login.microsoftonline.com/common")
  vite_redirect=$(prompt_env_value "VITE_ENTRA_REDIRECT_URI" "$(extract_env_value "$current_root" "VITE_ENTRA_REDIRECT_URI")" "Web redirect URI configured on the Entra app registration." "http://localhost:5173")
  vite_audience=$(prompt_env_value "VITE_API_AUDIENCE" "$(extract_env_value "$current_root" "VITE_API_AUDIENCE")" "API Application ID URI (audience), e.g. api://<app-client-id>." "api://purview-workbench")
  vite_api_base=$(prompt_env_value "VITE_API_BASE_URL" "$(extract_env_value "$current_root" "VITE_API_BASE_URL")" "Base URL for local API." "http://localhost:8000")

  api_client_id=$(prompt_env_value "API_ENTRA_CLIENT_ID" "$(extract_env_value "$current_root" "API_ENTRA_CLIENT_ID")" "Same Entra app Client ID validated by API token checks." "$vite_client_id")
  api_tenant_mode=$(prompt_env_value "API_ENTRA_TENANT_MODE" "$(extract_env_value "$current_root" "API_ENTRA_TENANT_MODE")" "Tenant mode from spec. Keep as multi-tenant unless explicitly changing architecture." "multi-tenant")
  api_audience=$(prompt_env_value "API_ALLOWED_AUDIENCE" "$(extract_env_value "$current_root" "API_ALLOWED_AUDIENCE")" "Expected JWT audience, should match VITE_API_AUDIENCE." "$vite_audience")
  api_db_url=$(prompt_env_value "API_DATABASE_URL" "$(extract_env_value "$current_root" "API_DATABASE_URL")" "SQLAlchemy DB URL. SQLite default is suitable for local setup." "sqlite:///./purview_workbench.db")
  api_consent_redirect=$(prompt_env_value "API_ADMIN_CONSENT_REDIRECT_URI" "$(extract_env_value "$current_root" "API_ADMIN_CONSENT_REDIRECT_URI")" "Frontend route used after admin consent completion." "${vite_redirect%/}/auth/consent-complete")

  cat >"$root_env" <<ENV
VITE_ENTRA_CLIENT_ID=$vite_client_id
VITE_ENTRA_AUTHORITY=$vite_authority
VITE_ENTRA_REDIRECT_URI=$vite_redirect
VITE_API_AUDIENCE=$vite_audience
VITE_API_BASE_URL=$vite_api_base
API_ENTRA_CLIENT_ID=$api_client_id
API_ENTRA_TENANT_MODE=$api_tenant_mode
API_ALLOWED_AUDIENCE=$api_audience
API_DATABASE_URL=$api_db_url
API_ADMIN_CONSENT_REDIRECT_URI=$api_consent_redirect
ENV

  cat >"$web_env" <<ENV
VITE_ENTRA_CLIENT_ID=$vite_client_id
VITE_ENTRA_AUTHORITY=$vite_authority
VITE_ENTRA_REDIRECT_URI=$vite_redirect
VITE_API_AUDIENCE=$vite_audience
VITE_API_BASE_URL=$vite_api_base
ENV

  cat >"$api_env" <<ENV
API_ENTRA_CLIENT_ID=$api_client_id
API_ENTRA_TENANT_MODE=$api_tenant_mode
API_ALLOWED_AUDIENCE=$api_audience
API_DATABASE_URL=$api_db_url
API_ADMIN_CONSENT_REDIRECT_URI=$api_consent_redirect
ENV

  log "Wrote .env, apps/web/.env.local, and apps/api/.env"
}

load_dotenv() {
  set -a
  # shellcheck disable=SC1090
  source "$ROOT_DIR/.env"
  set +a
}

validate_env_consistency() {
  load_dotenv
  [[ -n "${VITE_ENTRA_CLIENT_ID:-}" ]] || { err "VITE_ENTRA_CLIENT_ID is required"; exit 1; }
  [[ -n "${API_ENTRA_CLIENT_ID:-}" ]] || { err "API_ENTRA_CLIENT_ID is required"; exit 1; }
  [[ "$VITE_API_AUDIENCE" == "$API_ALLOWED_AUDIENCE" ]] || {
    err "VITE_API_AUDIENCE and API_ALLOWED_AUDIENCE must match"
    exit 1
  }
  [[ "$API_ENTRA_TENANT_MODE" == "multi-tenant" ]] || warn "API_ENTRA_TENANT_MODE is not multi-tenant"
  log "Environment values validated"
}

entra_setup() {
  load_dotenv
  echo
  echo "Microsoft Entra app registration setup mode:"
  echo "  1) use-existing"
  echo "  2) automatic (Azure CLI)"
  echo "  3) manual (show commands)"
  read -r -p "Choose [1/2/3] (default 1): " mode
  mode="${mode:-1}"

  if [[ "$mode" == "2" ]]; then
    command_exists az || { err "Azure CLI is required for automatic mode. Install az or use another mode."; exit 1; }
    az account show >/dev/null 2>&1 || { err "Run 'az login' first."; exit 1; }

    if az ad app show --id "$VITE_ENTRA_CLIENT_ID" >/dev/null 2>&1; then
      log "Using existing app registration: $VITE_ENTRA_CLIENT_ID"
    else
      log "Creating app registration"
      local create_out
      create_out=$(az ad app create \
        --display-name "PurviewWorkbench-Local" \
        --sign-in-audience AzureADMultipleOrgs \
        --web-redirect-uris "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI" \
        --query '{appId:appId}' -o tsv)
      VITE_ENTRA_CLIENT_ID="$create_out"
      API_ENTRA_CLIENT_ID="$create_out"
      VITE_API_AUDIENCE="api://$create_out"
      API_ALLOWED_AUDIENCE="$VITE_API_AUDIENCE"
      log "Created app: $create_out"
    fi

    az ad app update --id "$VITE_ENTRA_CLIENT_ID" --sign-in-audience AzureADMultipleOrgs >/dev/null
    az ad app update --id "$VITE_ENTRA_CLIENT_ID" --web-redirect-uris "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI" >/dev/null || true
    az ad app update --id "$VITE_ENTRA_CLIENT_ID" --identifier-uris "$VITE_API_AUDIENCE" >/dev/null || true

    az ad sp show --id "$VITE_ENTRA_CLIENT_ID" >/dev/null 2>&1 || az ad sp create --id "$VITE_ENTRA_CLIENT_ID" >/dev/null

    if az ad app permission admin-consent --id "$VITE_ENTRA_CLIENT_ID" >/dev/null 2>&1; then
      log "Admin consent granted automatically"
    else
      warn "Could not auto-grant admin consent. Grant manually then confirm."
    fi
  elif [[ "$mode" == "3" ]]; then
    cat <<MANUAL
Run the following commands after az login:
az ad app create --display-name PurviewWorkbench-Local --sign-in-audience AzureADMultipleOrgs --web-redirect-uris "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI"
az ad app update --id <APP_ID> --identifier-uris "$VITE_API_AUDIENCE"
az ad sp create --id <APP_ID>
az ad app permission admin-consent --id <APP_ID>
MANUAL
    read -r -p "Press Enter after completing manual setup..." _
  else
    log "Using existing Entra app registration values from env files"
  fi

  local signin_audience
  signin_audience=$(az ad app show --id "$VITE_ENTRA_CLIENT_ID" --query signInAudience -o tsv 2>/dev/null || echo "unknown")
  [[ "$signin_audience" == "AzureADMultipleOrgs" ]] || warn "App signInAudience is '$signin_audience' (expected AzureADMultipleOrgs)"

  local admin_consent_url
  admin_consent_url="https://login.microsoftonline.com/common/adminconsent?client_id=${VITE_ENTRA_CLIENT_ID}&redirect_uri=${API_ADMIN_CONSENT_REDIRECT_URI}"
  echo "Admin consent URL: $admin_consent_url"
  read -r -p "Confirm admin consent has been granted [y/N]: " consent_ok
  [[ "$consent_ok" =~ ^[Yy]$ ]] || { err "Admin consent must be completed before continuing."; exit 1; }

  cat >"$ROOT_DIR/.env" <<ENV
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
ENV

  log "Updated .env with validated Entra settings"
}

run_migrations() {
  load_dotenv
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv/bin/activate"
  (cd "$ROOT_DIR/apps/api" && SQLALCHEMY_URL="$API_DATABASE_URL" alembic upgrade head)
  deactivate
  log "Alembic migrations succeeded"
}

validate_setup() {
  install_prerequisites
  setup_venv
  validate_env_consistency
  run_migrations
  log "Validation complete"
}

run_api() {
  load_dotenv
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv/bin/activate"
  cd "$ROOT_DIR"
  exec python -m uvicorn src.main:app --reload --app-dir apps/api
}

run_web() {
  cd "$ROOT_DIR"
  exec pnpm --filter @purview/web dev
}

run_worker() {
  load_dotenv
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv/bin/activate"
  cd "$ROOT_DIR"
  exec python apps/worker/src/main.py
}

full_setup() {
  install_prerequisites
  setup_venv
  install_python_deps_if_needed
  install_js_deps_if_needed
  write_env_files
  validate_env_consistency
  entra_setup
  run_migrations
  log "Setup complete. Use './setup.sh run-api' and './setup.sh run-web'."
}

case "$MODE" in
  full) full_setup ;;
  run-api) run_api ;;
  run-web) run_web ;;
  run-worker) run_worker ;;
  validate) validate_setup ;;
  *)
    err "Unknown mode: $MODE"
    err "Usage: ./setup.sh [run-api|run-web|run-worker|validate]"
    exit 1
    ;;
esac

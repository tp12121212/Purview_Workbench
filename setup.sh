#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$ROOT_DIR/.setup"
STATE_FILE="$STATE_DIR/state.env"
mkdir -p "$STATE_DIR"

MODE="${1:-full}"
ENTRA_PERMISSION_COUNT=0

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
  local key="$1" current="$2" help="$3" default="$4" required="${5:-no}"

  if [[ -n "$current" ]]; then
    printf '[setup] %s\n' "$key already set; preserving existing value from .env" >&2
    echo "$current"
    return
  fi

  if [[ -n "$default" ]]; then
    printf '[setup] %s\n' "$key missing; using default value: $default" >&2
    echo "$default"
    return
  fi

  while true; do
    echo >&2
    echo "Required configuration: $key" >&2
    echo "Help: $help" >&2
    if [[ "$required" == "yes" ]]; then
      echo "This value has no safe default and is required to continue." >&2
    fi
    read -r -p "$key value (required, no default): " val >&2
    if [[ -n "${val:-}" ]]; then
      echo "$val"
      return
    fi
    echo "No value entered for $key. Please provide a non-empty value." >&2
  done
}

write_env_files() {
  local root_env="$ROOT_DIR/.env"
  local web_env="$ROOT_DIR/apps/web/.env.local"
  local api_env="$ROOT_DIR/apps/api/.env"

  local current_root="$root_env"
  [[ -f "$root_env" ]] || current_root="/dev/null"

  local vite_client_id vite_authority vite_redirect vite_audience vite_api_base
  local api_client_id api_tenant_mode api_audience api_db_url api_consent_redirect

  echo
  echo "Environment configuration (non-Entra values first)"
  echo "  Entra app registration selection/validation happens in the next step."

  vite_client_id="$(extract_env_value "$current_root" "VITE_ENTRA_CLIENT_ID")"
  vite_authority="$(extract_env_value "$current_root" "VITE_ENTRA_AUTHORITY")"
  vite_redirect="$(extract_env_value "$current_root" "VITE_ENTRA_REDIRECT_URI")"
  vite_audience="$(extract_env_value "$current_root" "VITE_API_AUDIENCE")"
  api_client_id="$(extract_env_value "$current_root" "API_ENTRA_CLIENT_ID")"
  api_audience="$(extract_env_value "$current_root" "API_ALLOWED_AUDIENCE")"
  api_consent_redirect="$(extract_env_value "$current_root" "API_ADMIN_CONSENT_REDIRECT_URI")"

  vite_authority="${vite_authority:-https://login.microsoftonline.com/common}"
  vite_redirect="${vite_redirect:-http://localhost:5173}"
  vite_audience="${vite_audience:-api://purview-workbench}"
  api_consent_redirect="${api_consent_redirect:-${vite_redirect%/}/auth/consent-complete}"
  vite_api_base=$(prompt_env_value "VITE_API_BASE_URL" "$(extract_env_value "$current_root" "VITE_API_BASE_URL")" "Base URL for local API used by the web app." "http://localhost:8000")
  api_tenant_mode=$(prompt_env_value "API_ENTRA_TENANT_MODE" "$(extract_env_value "$current_root" "API_ENTRA_TENANT_MODE")" "Tenant mode from architecture. Keep as multi-tenant unless intentionally changing design." "multi-tenant")
  api_db_url=$(prompt_env_value "API_DATABASE_URL" "$(extract_env_value "$current_root" "API_DATABASE_URL")" "SQLAlchemy DB URL. SQLite default is suitable for local development." "sqlite:///./purview_workbench.db")

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

write_env_bundle() {
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

  cat >"$ROOT_DIR/apps/web/.env.local" <<ENV
VITE_ENTRA_CLIENT_ID=$VITE_ENTRA_CLIENT_ID
VITE_ENTRA_AUTHORITY=$VITE_ENTRA_AUTHORITY
VITE_ENTRA_REDIRECT_URI=$VITE_ENTRA_REDIRECT_URI
VITE_API_AUDIENCE=$VITE_API_AUDIENCE
VITE_API_BASE_URL=$VITE_API_BASE_URL
ENV

  cat >"$ROOT_DIR/apps/api/.env" <<ENV
API_ENTRA_CLIENT_ID=$API_ENTRA_CLIENT_ID
API_ENTRA_TENANT_MODE=$API_ENTRA_TENANT_MODE
API_ALLOWED_AUDIENCE=$API_ALLOWED_AUDIENCE
API_DATABASE_URL=$API_DATABASE_URL
API_ADMIN_CONSENT_REDIRECT_URI=$API_ADMIN_CONSENT_REDIRECT_URI
ENV
}

is_guid_like() {
  [[ "$1" =~ ^[0-9a-fA-F-]{32,36}$ ]]
}

require_az_cli_session() {
  command_exists az || {
    err "Azure CLI is required for Entra setup/validation."
    err "Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
    exit 1
  }
  az account show >/dev/null 2>&1 || {
    err "Azure CLI is not logged in."
    err "Run: az login"
    exit 1
  }
}

ensure_sp_exists() {
  local client_id="$1"
  local create_output
  if az ad sp show --id "$client_id" >/dev/null 2>&1; then
    return 0
  fi
  warn "Service principal was missing; creating it now."
  if create_output="$(az ad sp create --id "$client_id" 2>&1)"; then
    return 0
  fi
  if echo "$create_output" | grep -qi "already in use"; then
    warn "Service principal appears to already exist (Azure CLI returned 'already in use'). Continuing."
    return 0
  fi
  err "Failed to create service principal for $client_id"
  err "$create_output"
  return 1
}

get_scope_id() {
  local resource_app_id="$1"
  local scope_value="$2"
  az ad sp show --id "$resource_app_id" --query "oauth2PermissionScopes[?value=='$scope_value'].id | [0]" -o tsv 2>/dev/null || true
}

add_scope_permission_if_missing() {
  local client_id="$1"
  local resource_app_id="$2"
  local scope_value="$3"
  local scope_id output

  scope_id="$(get_scope_id "$resource_app_id" "$scope_value")"
  if [[ -z "$scope_id" ]]; then
    warn "Scope '$scope_value' not found on resource app '$resource_app_id'; skipping."
    return 0
  fi

  if output="$(az ad app permission add --id "$client_id" --api "$resource_app_id" --api-permissions "${scope_id}=Scope" 2>&1)"; then
    log "Ensured delegated scope '$scope_value' on app $client_id"
    return 0
  fi

  if echo "$output" | grep -Eqi "already exists|already assigned|permission being added already exists"; then
    log "Delegated scope '$scope_value' already present on app $client_id"
    return 0
  fi

  warn "Could not add scope '$scope_value' to app $client_id: $output"
  return 0
}

ensure_baseline_permissions() {
  local client_id="$1"
  local graph_app_id="00000003-0000-0000-c000-000000000000"

  log "Ensuring baseline delegated permissions for local scaffold."
  add_scope_permission_if_missing "$client_id" "$graph_app_id" "openid"
  add_scope_permission_if_missing "$client_id" "$graph_app_id" "profile"
  add_scope_permission_if_missing "$client_id" "$graph_app_id" "email"
  add_scope_permission_if_missing "$client_id" "$graph_app_id" "offline_access"
  add_scope_permission_if_missing "$client_id" "$graph_app_id" "User.Read"
}

validate_entra_registration() {
  local client_id="$1"
  local _redirects_csv="$2"
  local issues=0
  local app_json signin audience redirects has_sp perm_count

  app_json="$(az ad app show --id "$client_id" -o json 2>/dev/null || true)"
  if [[ -z "$app_json" ]]; then
    err "Entra app registration not found for client ID: $client_id"
    return 1
  fi

  signin="$(printf '%s' "$app_json" | "$PYTHON_BIN" -c 'import json,sys; print(json.load(sys.stdin).get("signInAudience",""))')"
  if [[ "$signin" != "AzureADMultipleOrgs" ]]; then
    err "signInAudience is '$signin' (expected AzureADMultipleOrgs)."
    issues=1
  fi

  audience="$(printf '%s' "$app_json" | "$PYTHON_BIN" -c 'import json,sys; u=json.load(sys.stdin).get("identifierUris",[]); print(u[0] if u else "")')"
  if [[ -z "$audience" ]]; then
    err "No identifier URI configured on app registration. Expected: $VITE_API_AUDIENCE"
    issues=1
  elif [[ "$audience" != "$VITE_API_AUDIENCE" ]]; then
    err "Identifier URI mismatch. Current: $audience, Expected: $VITE_API_AUDIENCE"
    issues=1
  fi

  redirects="$(printf '%s' "$app_json" | "$PYTHON_BIN" -c 'import json,sys; r=(json.load(sys.stdin).get("web",{}) or {}).get("redirectUris",[]); print(",".join(r))')"
  for expected in "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI"; do
    if [[ "$redirects" != *"$expected"* ]]; then
      err "Missing required redirect URI on app registration: $expected"
      issues=1
    fi
  done

  if az ad sp show --id "$client_id" >/dev/null 2>&1; then
    has_sp=1
  else
    has_sp=0
  fi
  if [[ "$has_sp" -eq 0 ]]; then
    err "Service principal does not exist for app: $client_id"
    issues=1
  fi

  perm_count="$(az ad app permission list --id "$client_id" --query 'length([])' -o tsv 2>/dev/null || echo 0)"
  ENTRA_PERMISSION_COUNT="$perm_count"
  if [[ "$perm_count" == "0" ]]; then
    warn "No app permission entries found. This scaffold currently uses minimal delegated/dev token flow."
  fi

  if [[ "$issues" -ne 0 ]]; then
    echo
    echo "Remediation commands:"
    echo "  az ad app update --id \"$client_id\" --sign-in-audience AzureADMultipleOrgs"
    echo "  az ad app update --id \"$client_id\" --web-redirect-uris \"$VITE_ENTRA_REDIRECT_URI\" \"$API_ADMIN_CONSENT_REDIRECT_URI\""
    echo "  az ad app update --id \"$client_id\" --identifier-uris \"$VITE_API_AUDIENCE\""
    echo "  az ad sp show --id \"$client_id\" || az ad sp create --id \"$client_id\""
    echo "  # If create returns 'already in use', treat that as already existing."
    return 1
  fi

  log "Entra registration validation passed for $client_id"
  return 0
}

confirm_admin_consent() {
  local client_id="$1"
  local tenant_context="$2"
  local admin_consent_url="https://login.microsoftonline.com/${tenant_context}/adminconsent?client_id=${client_id}&redirect_uri=${API_ADMIN_CONSENT_REDIRECT_URI}"
  local consent_ok
  local consent_output

  if [[ "${ENTRA_PERMISSION_COUNT:-0}" == "0" ]]; then
    warn "Skipping admin consent step because app registration has no configured permission entries."
    return 0
  fi

  if consent_output="$(az ad app permission admin-consent --id "$client_id" 2>&1)"; then
    log "Admin consent granted automatically via Azure CLI."
    return 0
  fi

  if echo "$consent_output" | grep -Eqi "AADSTS1003031|misconfigured"; then
    warn "Admin consent endpoint returned misconfigured/no-required-permissions error."
    warn "Proceeding because this scaffold currently has no mandatory permission grants."
    return 0
  fi

  warn "Automatic admin consent did not complete."
  echo "Manual admin consent is required before setup can continue."
  echo "  1) Open this URL in a browser as tenant admin:"
  echo "     $admin_consent_url"
  echo "  2) Approve consent and wait for redirect to:"
  echo "     $API_ADMIN_CONSENT_REDIRECT_URI"
  while true; do
    read -r -p "Confirm admin consent is complete [y/N]: " consent_ok
    if [[ "$consent_ok" =~ ^[Yy]$ ]]; then
      return 0
    fi
    err "Admin consent confirmation is required to proceed."
  done
}

entra_setup() {
  load_dotenv
  local flow_choice existing_choice app_name selected_id tenant_context current_tenant_id

  require_az_cli_session
  current_tenant_id="$(az account show --query tenantId -o tsv 2>/dev/null || echo "")"
  tenant_context="common"

  echo
  echo "Microsoft Entra ID app registration is required for this application."
  echo "Why this is needed:"
  echo "  - Web auth configuration requires an Entra application client ID."
  echo "  - API token audience/client checks depend on the same app registration."
  echo "  - Admin consent is required for tenant-scoped protected actions."
  echo "This setup step configures and validates the registration before Entra env values are finalized."

  while true; do
    echo
    echo "Microsoft Entra app registration flow:"
    echo "  A) use existing app registration"
    echo "     - Enter an existing client ID"
    echo "     - Script validates app existence, multitenant audience, redirect URIs, API audience, and SP"
    echo "  B) create new app registration"
    echo "     - Script creates and configures a new multitenant app via Azure CLI"
    echo "     - Script sets redirect URIs, identifier URI, and service principal"
    read -r -p "Choose [A/B] (default A): " flow_choice
    flow_choice="${flow_choice:-A}"
    flow_choice="$(printf '%s' "$flow_choice" | tr '[:lower:]' '[:upper:]')"

    if [[ "$flow_choice" == "A" ]]; then
      while true; do
        echo
        read -r -p "Tenant ID for validation/admin-consent URL context [${current_tenant_id:-common}]: " tenant_context
        tenant_context="${tenant_context:-${current_tenant_id:-common}}"
        if [[ -n "$current_tenant_id" && "$tenant_context" != "common" && "$tenant_context" != "$current_tenant_id" ]]; then
          warn "Provided tenant ID differs from current Azure CLI tenant ($current_tenant_id)."
        fi

        read -r -p "Existing Entra app client ID [${VITE_ENTRA_CLIENT_ID}]: " selected_id
        selected_id="${selected_id:-$VITE_ENTRA_CLIENT_ID}"
        if ! is_guid_like "$selected_id"; then
          err "Client ID format looks invalid. Expected GUID-like value."
          continue
        fi

        VITE_ENTRA_CLIENT_ID="$selected_id"
        API_ENTRA_CLIENT_ID="$selected_id"
        if [[ "$VITE_API_AUDIENCE" == "api://purview-workbench" ]]; then
          VITE_API_AUDIENCE="api://$selected_id"
          API_ALLOWED_AUDIENCE="$VITE_API_AUDIENCE"
          warn "Updated API audience to match selected app: $VITE_API_AUDIENCE"
        fi

        if validate_entra_registration "$selected_id" "$VITE_ENTRA_REDIRECT_URI,$API_ADMIN_CONSENT_REDIRECT_URI"; then
          ensure_sp_exists "$selected_id"
          if [[ "${ENTRA_PERMISSION_COUNT:-0}" == "0" ]]; then
            echo
            warn "No permission entries found on existing app registration."
            read -r -p "Add baseline delegated permissions now (openid/profile/email/offline_access/User.Read)? [Y/n]: " add_baseline
            add_baseline="${add_baseline:-Y}"
            if [[ "$add_baseline" =~ ^[Yy]$ ]]; then
              ensure_baseline_permissions "$selected_id"
              validate_entra_registration "$selected_id" "$VITE_ENTRA_REDIRECT_URI,$API_ADMIN_CONSENT_REDIRECT_URI" || true
            fi
          fi
          break
        fi

        echo
        echo "Validation failed. Next action:"
        echo "  R) retry existing app values after remediation"
        echo "  S) switch to create-new flow"
        echo "  C) continue after manual fixes (best-effort)"
        echo "  Q) quit setup now"
        read -r -p "Choose [R/S/C/Q] (default R): " existing_choice
        existing_choice="${existing_choice:-R}"
        existing_choice="$(printf '%s' "$existing_choice" | tr '[:lower:]' '[:upper:]')"
        if [[ "$existing_choice" == "S" ]]; then
          flow_choice="B"
          break
        elif [[ "$existing_choice" == "C" ]]; then
          warn "Continuing with user-confirmed manual fixes."
          break
        elif [[ "$existing_choice" == "Q" ]]; then
          err "Setup aborted by user."
          exit 1
        fi
      done
      if [[ "$flow_choice" == "B" ]]; then
        continue
      fi
      break
    fi

    if [[ "$flow_choice" == "B" ]]; then
      read -r -p "Tenant ID for app creation/admin-consent URL context [${current_tenant_id:-common}]: " tenant_context
      tenant_context="${tenant_context:-${current_tenant_id:-common}}"
      read -r -p "New app registration name [PurviewWorkbench-Local]: " app_name
      app_name="${app_name:-PurviewWorkbench-Local}"

      log "Creating new Entra app registration '$app_name'"
      selected_id="$(az ad app create \
        --display-name "$app_name" \
        --sign-in-audience AzureADMultipleOrgs \
        --web-redirect-uris "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI" \
        --query appId -o tsv)"

      VITE_ENTRA_CLIENT_ID="$selected_id"
      API_ENTRA_CLIENT_ID="$selected_id"
      VITE_API_AUDIENCE="api://$selected_id"
      API_ALLOWED_AUDIENCE="$VITE_API_AUDIENCE"

      az ad app update --id "$selected_id" --sign-in-audience AzureADMultipleOrgs >/dev/null
      az ad app update --id "$selected_id" --web-redirect-uris "$VITE_ENTRA_REDIRECT_URI" "$API_ADMIN_CONSENT_REDIRECT_URI" >/dev/null
      az ad app update --id "$selected_id" --identifier-uris "$VITE_API_AUDIENCE" >/dev/null
      ensure_sp_exists "$selected_id"
      ensure_baseline_permissions "$selected_id"

      if ! validate_entra_registration "$selected_id" "$VITE_ENTRA_REDIRECT_URI,$API_ADMIN_CONSENT_REDIRECT_URI"; then
        err "Created app validation failed."
        err "Review messages above, fix manually, and rerun setup."
        exit 1
      fi
      break
    fi

    err "Invalid choice. Enter A or B."
  done

  confirm_admin_consent "$VITE_ENTRA_CLIENT_ID" "$tenant_context"
  write_env_bundle
  log "Updated .env, apps/web/.env.local, and apps/api/.env with validated Entra settings"
}

run_migrations() {
  load_dotenv
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.venv/bin/activate"
  (cd "$ROOT_DIR/apps/api" && SQLALCHEMY_URL="$API_DATABASE_URL" alembic upgrade head)
  deactivate
  log "Alembic migrations succeeded"
}

print_next_steps() {
  echo
  echo "Next steps"
  echo "  1) Activate Python virtual environment:"
  echo "     source .venv/bin/activate"
  echo "  2) Start API (terminal 1):"
  echo "     python -m uvicorn src.main:app --reload --app-dir apps/api"
  echo "  3) Start Web (terminal 2):"
  echo "     pnpm --filter @purview/web dev"
  echo "  4) Start Worker (optional, terminal 3):"
  echo "     python apps/worker/src/main.py"
}

validate_setup() {
  install_prerequisites
  setup_venv
  validate_env_consistency
  run_migrations
  log "Validation complete"
  print_next_steps
}

full_setup() {
  install_prerequisites
  setup_venv
  install_python_deps_if_needed
  install_js_deps_if_needed
  write_env_files
  entra_setup
  validate_env_consistency
  run_migrations
  log "Setup complete."
  print_next_steps
}

case "$MODE" in
  full) full_setup ;;
  validate) validate_setup ;;
  *)
    err "Unknown mode: $MODE"
    err "Usage: ./setup.sh [validate]"
    exit 1
    ;;
esac

exit 0

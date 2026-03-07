# Purview Workbench Setup

This repository includes cross-platform setup entry points:

- macOS/Linux: `./setup.sh`
- Windows: `setup.cmd` (launches `setup.ps1`)

## Supported run modes

### macOS/Linux

```bash
./setup.sh
./setup.sh run-api
./setup.sh run-web
./setup.sh run-worker
./setup.sh validate
```

### Windows

```powershell
setup.cmd
setup.cmd run-api
setup.cmd run-web
setup.cmd run-worker
setup.cmd validate
```

## What full setup does

`full` mode performs an idempotent local setup for the current repository layout:

1. Checks prerequisites (Node.js, pnpm, Python 3.12+)
2. Creates `.venv` if missing
3. Installs Python dependencies only when API/worker manifests changed
4. Installs JavaScript dependencies only when `pnpm-lock.yaml` changed
5. Prompts for required env values and writes:
   - `.env`
   - `apps/web/.env.local`
   - `apps/api/.env`
6. Performs Microsoft Entra app registration workflow:
   - Use existing registration
   - Automatic creation/configuration (Azure CLI)
   - Manual creation instructions
7. Requires explicit admin-consent confirmation
8. Validates key settings consistency
9. Runs Alembic migration (`apps/api/alembic upgrade head`)

## Required environment values

The setup scripts prompt for and preserve existing values where available:

- `VITE_ENTRA_CLIENT_ID`
- `VITE_ENTRA_AUTHORITY`
- `VITE_ENTRA_REDIRECT_URI`
- `VITE_API_AUDIENCE`
- `VITE_API_BASE_URL`
- `API_ENTRA_CLIENT_ID`
- `API_ENTRA_TENANT_MODE`
- `API_ALLOWED_AUDIENCE`
- `API_DATABASE_URL`
- `API_ADMIN_CONSENT_REDIRECT_URI`

## Microsoft Entra setup details

### Automatic mode

Uses Azure CLI (`az`) to:

- create the app registration if missing
- enforce `AzureADMultipleOrgs` sign-in audience
- configure web/admin-consent redirect URIs
- configure API identifier URI
- ensure service principal exists
- attempt admin-consent automation

If admin-consent automation fails, the script prints the consent URL and requires confirmation before continuing.

### Manual mode

The script prints exact `az` commands and expected values, then waits for user confirmation.

## Validation performed

- Python version is 3.12+
- Required env values exist
- `VITE_API_AUDIENCE` equals `API_ALLOWED_AUDIENCE`
- warns if `API_ENTRA_TENANT_MODE != multi-tenant`
- Alembic migration completes

## Limitations and assumptions

- macOS/Linux auto-install attempts use available package managers (`brew` / `apt-get`) and may still require elevated privileges.
- Windows prerequisite installation is not forced automatically; actionable guidance is provided when missing.
- The setup scripts do not store secrets in git-tracked files.
- API environment variables are sourced by setup run commands and mirrored into `apps/api/.env` for operator clarity.
- Current scaffold does not declare additional API permissions beyond app registration and consent flow, so permission-specific enforcement is limited to app/SP/consent validation.

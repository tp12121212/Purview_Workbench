# Purview Workbench Setup

This repository includes cross-platform setup entry points:

- macOS/Linux: `./setup.sh`
- Windows: `setup.cmd` (launches `setup.ps1`)

## Supported run modes

### macOS/Linux

```bash
./setup.sh
./setup.sh validate
```

### Windows

```powershell
setup.cmd
setup.cmd validate
```

### Running apps after setup

Use the standard app commands after setup completes:

```bash
pnpm --filter @purview/web dev
python -m uvicorn src.main:app --reload --app-dir apps/api
python apps/worker/src/main.py
```

## What full setup does

`full` mode performs an idempotent local setup for the current repository layout:

1. Checks prerequisites (Node.js, pnpm, Python 3.12+)
2. Creates `.venv` if missing
3. Installs Python dependencies only when API/worker manifests changed
4. Installs JavaScript dependencies only when `pnpm-lock.yaml` changed
5. Prompts only for non-Entra required values first (existing values are preserved and safe defaults are auto-applied), then writes baseline env files
 - `.env`
 - `apps/web/.env.local`
 - `apps/api/.env`
6. Shows Entra setup help text and performs Microsoft Entra app registration workflow before final Entra env values are set:
   - `A)` use existing registration (with validation/remediation loop)
   - `B)` create new registration (Azure CLI automation)
7. Handles admin consent inside the Entra flow (automation attempt + manual confirmation gate if needed)
8. Validates key settings consistency
9. Runs Alembic migration (`apps/api/alembic upgrade head`)

## Required environment values

The setup scripts preserve existing values and automatically apply safe defaults where available. They only prompt for values that are required and have no default:

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

All interactive prompts include detailed help text describing what each option/value means and when to use it.

## Microsoft Entra setup details

### Flow A: Use existing app registration

The script prompts for the existing client ID and validates:

- app registration exists
- sign-in audience is `AzureADMultipleOrgs`
- required redirect URIs are configured
- identifier URI matches expected API audience
- service principal exists
- permission entries are queryable (warns if empty for current scaffold)

If validation fails, the script shows remediation commands and prompts to:

- retry after remediation
- switch to create-new flow
- continue after manual fixes (best effort)
- quit setup

### Flow B: Create new app registration

Uses Azure CLI (`az`) to:

- create a new app registration (default name `PurviewWorkbench-Local`, customizable)
- configure `AzureADMultipleOrgs` sign-in audience
- configure required redirect URIs
- configure identifier URI (API audience)
- ensure service principal exists
- validate created registration with the same checks as Flow A

If any required step cannot be validated, setup fails with actionable remediation output.

### Admin consent

The script attempts `az ad app permission admin-consent` first.  
If it cannot complete automatically, setup pauses and prints:

- exact admin-consent URL
- required redirect URI
- explicit confirmation gate (`y`) before continuing

## Validation performed

- Python version is 3.12+
- Required env values exist
- `VITE_API_AUDIENCE` equals `API_ALLOWED_AUDIENCE`
- warns if `API_ENTRA_TENANT_MODE != multi-tenant`
- Entra app registration checks listed above
- Alembic migration completes

## Limitations and assumptions

- macOS/Linux auto-install attempts use available package managers (`brew` / `apt-get`) and may still require elevated privileges.
- Windows prerequisite installation is not forced automatically; actionable guidance is provided when missing.
- The setup scripts do not store secrets in git-tracked files.
- API environment variables are sourced by setup run commands and mirrored into `apps/api/.env` for operator clarity.
- Current scaffold does not declare additional API permissions beyond app registration and consent flow, so permission-specific enforcement is limited to app/SP/consent validation.
- Entra validation is Azure CLI based; if `az` lacks tenant/application read permissions, validation may require operator remediation and rerun.

# Purview Workbench (Phase 1 Scaffold)

This repository implements the Phase 0 scaffold and Phase 1 auth/onboarding + tenancy persistence from `spec/build-pack/v0.1`.

## One-command setup

Use the integrated setup scripts for end-to-end local bootstrap and run modes:

```bash
./setup.sh
./setup.sh run-api
./setup.sh run-web
./setup.sh run-worker
./setup.sh validate
```

Windows:

```powershell
setup.cmd
setup.cmd run-api
setup.cmd run-web
setup.cmd run-worker
setup.cmd validate
```

See `docs/setup.md` for full details, Entra app registration modes, and limitations.

## Workspace commands

```bash
pnpm install
pnpm dev
pnpm lint
pnpm test
pnpm typecheck
```

## Environment

Copy `.env.example` and set values for local runs:

```bash
cp .env.example .env
```

Phase 1 env variables:

- Web (`apps/web`): `VITE_ENTRA_CLIENT_ID`, `VITE_ENTRA_AUTHORITY`, `VITE_ENTRA_REDIRECT_URI`, `VITE_API_AUDIENCE`, `VITE_API_BASE_URL`
- API (`apps/api`): `API_ENTRA_CLIENT_ID`, `API_ENTRA_TENANT_MODE=multi-tenant`, `API_ALLOWED_AUDIENCE`, `API_DATABASE_URL`, `API_ADMIN_CONSENT_REDIRECT_URI`

## App run notes

- `apps/web`: React + Vite auth/onboarding shell (`pnpm --filter @purview/web dev`)
- `apps/api`: FastAPI API with `/api/v1` auth + tenant routes (`python -m uvicorn src.main:app --reload --app-dir apps/api`)
- `apps/worker`: Python worker placeholder (`python apps/worker/src/main.py`)

## Phase 1 backend endpoints

- `GET /api/v1/me`
- `GET /api/v1/tenants/me`
- `GET /api/v1/tenants/me/consent-status`
- `POST /api/v1/tenants/consent-complete`

## Database migrations

From `apps/api`:

```bash
alembic upgrade head
```

## Tests

- API route tests: `cd apps/api && python -m pytest`
- Web auth/onboarding rendering tests: `pnpm --filter @purview/web test`
- Existing placeholders remain under `tests/e2e`, `tests/api`, and `tests/worker`

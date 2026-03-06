# API (Phase 1)

FastAPI backend for Purview Workbench.

## Local run

```bash
cd apps/api
python -m uvicorn src.main:app --reload
```

## Routes added in Phase 1

- `GET /api/v1/me`
- `GET /api/v1/tenants/me`
- `GET /api/v1/tenants/me/consent-status`
- `POST /api/v1/tenants/consent-complete`

## Migrations

```bash
cd apps/api
alembic upgrade head
```

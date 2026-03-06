# Purview Workbench (Phase 0 Scaffold)

This repository is scaffolded per `spec/build-pack/v0.1/phase-0.md`.

## Workspace commands

```bash
pnpm install
pnpm dev
pnpm lint
pnpm test
pnpm typecheck
```

## App run notes

- `apps/web`: React + Vite placeholder app (`pnpm --filter @purview/web dev`)
- `apps/api`: FastAPI placeholder API (`python -m uvicorn src.main:app --reload --app-dir apps/api`)
- `apps/worker`: Python worker skeleton (`python apps/worker/src/main.py`)

## Tests

- `tests/e2e`: Playwright placeholder
- `tests/api`: pytest placeholder
- `tests/worker`: PowerShell Pester placeholder

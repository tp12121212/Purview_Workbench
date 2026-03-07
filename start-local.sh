#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if [[ ! -d ".venv" ]]; then
  echo "[start] Missing .venv. Run ./setup.sh first."
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "[start] pnpm is required but was not found on PATH."
  exit 1
fi

cleanup() {
  echo
  echo "[start] Stopping API/Web/Worker..."
  jobs -p | xargs -r kill 2>/dev/null || true
}

trap cleanup INT TERM EXIT

(
  source .venv/bin/activate
  python -m uvicorn src.main:app --reload --app-dir apps/api 2>&1 | sed 's/^/[api] /'
) &

(
  pnpm --filter @purview/web dev 2>&1 | sed 's/^/[web] /'
) &

(
  source .venv/bin/activate
  python apps/worker/src/main.py 2>&1 | sed 's/^/[worker] /'
) &

echo "[start] Running services"
echo "[start] Web: http://localhost:5173"
echo "[start] API: http://localhost:8000"
echo "[start] Press Ctrl+C to stop all"

wait

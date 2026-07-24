#!/usr/bin/env bash
# Validate the environment: required tools, Docker, backend health.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0

check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo "  ✓ $1 -> $(command -v "$1")"
  else
    echo "  ✗ $1 not found"; fail=1
  fi
}

echo "==> Tools"
check node
check npm
check docker
# flutter may not be on PATH; fall back to common location
if command -v flutter >/dev/null 2>&1; then
  echo "  ✓ flutter -> $(command -v flutter)"
elif [ -x "$HOME/flutter/bin/flutter" ]; then
  echo "  ✓ flutter -> $HOME/flutter/bin/flutter"
else
  echo "  ✗ flutter not found"; fail=1
fi

echo "==> Node version"
node -v | grep -q "v22" && echo "  ✓ Node 22" || { echo "  ✗ Node 22 LTS required"; fail=1; }

echo "==> Docker services"
docker compose -f docker/docker-compose.yml ps postgres >/dev/null 2>&1 || true
docker compose -f docker/docker-compose.yml ps | grep -q healthy && echo "  ✓ postgres healthy" || echo "  ⚠ postgres not running/healthy (run scripts/setup.sh)"

if [ "$fail" -ne 0 ]; then
  echo "Validation FAILED."
  exit 1
fi
echo "Validation OK."
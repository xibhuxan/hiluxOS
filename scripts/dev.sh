#!/usr/bin/env bash
# Start the full development stack: PostgreSQL (Docker) + NestJS backend.
# Flutter is started separately (see scripts/run-app.sh) since it is interactive.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Ensuring PostgreSQL is running..."
docker compose -f docker/docker-compose.yml up -d
echo "    Waiting for postgres to be healthy..."
until docker compose -f docker/docker-compose.yml ps postgres | grep -q "healthy"; do
  printf "."; sleep 2
done
echo " ok"

echo "==> Starting NestJS backend (watch mode on :3000)..."
cd backend
exec npm run start:dev
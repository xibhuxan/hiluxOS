#!/usr/bin/env bash
# One-time environment setup for hiluxOS development.
# Boots PostgreSQL in Docker, installs backend deps, runs Prisma migration.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Starting PostgreSQL (Docker)..."
docker compose -f docker/docker-compose.yml up -d
echo "    Waiting for postgres to be healthy..."
until docker compose -f docker/docker-compose.yml ps postgres | grep -q "healthy"; do
  printf "."; sleep 2
done
echo " ok"

echo "==> Installing backend dependencies..."
cd backend
npm install

echo "==> Generating Prisma client + applying migration..."
npm run db:migrate

echo "==> Setup complete."
echo "    Start everything with: scripts/dev.sh"
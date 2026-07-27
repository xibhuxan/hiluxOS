#!/usr/bin/env bash
# Build and launch the Flutter app on Linux desktop with hot reload.
#   Press  r  in this terminal to hot-reload UI changes instantly.
#   Press  R  to perform a full hot restart.
#   Press  h  for all available commands.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/app"

echo "==> Installing dependencies..."
flutter pub get

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Hot reload enabled — press  r  in this terminal    ║"
echo "║  to apply code changes without restarting the app.  ║"
echo "║  Press  R  for a full hot restart.                 ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

exec flutter run -d linux --debug

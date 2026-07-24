#!/usr/bin/env bash
# Build and launch the Flutter app on Linux desktop.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/app"

flutter pub get
exec flutter run -d linux
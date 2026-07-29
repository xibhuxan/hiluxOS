#!/usr/bin/env bash
#
# hiluxOS — build + upload the Flutter UI bundle to a GitHub Release.
#
# Compiles the Flutter app for Linux desktop (release), tars the bundle, and
# uploads it as an asset to the GitHub Release matching VERSION.txt. The asset
# is named by architecture so the installer can pick the right one:
#
#   hiluxos-ui-<arch>.tar.gz   (e.g. hiluxos-ui-x86-64.tar.gz)
#
# Usage:
#   scripts/release-ui.sh              # builds current arch, uploads to VERSION.txt release
#   scripts/release-ui.sh --arm64      # cross-compile arm64 (needs flutter + arm64 toolchain)
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Flutter SDK in PATH
#   - The API URL is baked in at build time via --dart-define.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT/app"
VERSION_FILE="$ROOT/VERSION.txt"

# ── gh must be available and authenticated ────────────────────────────
command -v gh &>/dev/null || { echo "✗ gh CLI not found. Install it: https://cli.github.com"; exit 1; }
gh auth status &>/dev/null || { echo "✗ gh not authenticated. Run: gh auth login"; exit 1; }

# ── flutter must be available ─────────────────────────────────────────
command -v flutter &>/dev/null || { echo "✗ flutter not in PATH"; exit 1; }

# ── Determine version + architecture ──────────────────────────────────
[[ -f "$VERSION_FILE" ]] || { echo "✗ VERSION.txt not found at $VERSION_FILE"; exit 1; }
VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

ARCH_TARGET=""
if [[ "${1:-}" == "--arm64" ]]; then
  ARCH_TARGET="arm64"
  echo "⚠ arm64 cross-compile requested — this requires a Flutter arm64 toolchain."
  echo "  If flutter cannot target arm64, this will fail."
fi

# Detect host arch for naming the asset.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64)  ASSET_ARCH="x86-64" ;;
  aarch64) ASSET_ARCH="arm64" ;;
  *)       ASSET_ARCH="$HOST_ARCH" ;;
esac

# Override with explicit target if given.
if [[ -n "$ARCH_TARGET" ]]; then
  ASSET_ARCH="$ARCH_TARGET"
fi

ASSET_NAME="hiluxos-ui-${ASSET_ARCH}.tar.gz"

echo "==> Version:  $VERSION"
echo "==> Asset:    $ASSET_NAME"

# ── Build the Flutter app ─────────────────────────────────────────────
echo "==> Building Flutter Linux release bundle..."
cd "$APP_DIR"
flutter pub get
flutter build linux --release \
  --dart-define=APP_API_URL=http://localhost:3000 \
  --dart-define=APP_WS_URL=ws://localhost:3000/events

# Locate the bundle directory.
BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle"
[[ -d "$BUNDLE_DIR" ]] || BUNDLE_DIR="$APP_DIR/build/linux/arm64/release/bundle"
[[ -d "$BUNDLE_DIR" ]] || { echo "✗ Bundle directory not found after build"; exit 1; }

# ── Tar the bundle ────────────────────────────────────────────────────
TARBALL="/tmp/$ASSET_NAME"
echo "==> Packaging → $TARBALL"
cd "$(dirname "$BUNDLE_DIR")"
tar czf "$TARBALL" "$(basename "$BUNDLE_DIR")"
ls -lh "$TARBALL"

# ── Create the release if it doesn't exist, then upload (clobber) ─────
echo "==> Uploading to GitHub Release v$VERSION..."
cd "$ROOT"

if gh release view "v$VERSION" &>/dev/null; then
  echo "  Release v$VERSION exists — uploading asset (clobbering old one)..."
  gh release upload "v$VERSION" "$TARBALL" --clobber
else
  echo "  Release v$VERSION does not exist — creating it..."
  gh release create "v$VERSION" "$TARBALL" \
    --title "hiluxOS v$VERSION" \
    --notes "Release v$VERSION. UI bundle: $ASSET_ARCH."
fi

echo ""
echo "✓ Done. Asset uploaded:"
echo "  https://github.com/xibhuxan/hiluxOS/releases/download/v${VERSION}/${ASSET_NAME}"
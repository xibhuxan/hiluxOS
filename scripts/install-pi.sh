#!/usr/bin/env bash
#
# hiluxOS — first-time installer for Debian-minimal (Raspberry Pi).
#
# Installs everything from scratch: Node.js 22 LTS, PostgreSQL, git, the
# backend, and a systemd service. After this, OTA updates work from the app.
#
# Usage (as root or with sudo):
#   curl -fsSL https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/scripts/install-pi.sh | sudo bash
#
# Or after cloning manually:
#   sudo bash scripts/install-pi.sh
#
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────
INSTALL_ROOT="/opt/hiluxos"
REPO_URL="https://github.com/xibhuxan/hiluxOS.git"
DB_USER="hiluxos"
DB_PASS="hiluxos_dev"
DB_NAME="hiluxos"
NODE_MAJOR=22
SERVICE_USER="hiluxos"
LOG_FILE="/var/log/hiluxos-install.log"
# ──────────────────────────────────────────────────────────────────────

log()  { echo -e "\033[1;34m==>\033[0m $*"; }
ok()   { echo -e "\033[1;32m  ✓\033[0m $*"; }
die()  { echo -e "\033[1;31m  ✗\033[0m $*" >&2; exit 1; }

# Must be root
[[ "$(id -u)" -eq 0 ]] || die "Run with sudo: sudo bash scripts/install-pi.sh"

# ── Logging: tee everything to /var/log/hiluxos-install.log ───────────
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
chmod 640 "$LOG_FILE"

# Write a banner header so multiple runs are easy to tell apart.
{
  echo ""
  echo "================================================================"
  echo " hiluxOS install — $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Invoked as: $0 $*"
  echo "================================================================"
} >> "$LOG_FILE"

# Redirect stdout+stderr through tee so the user sees output on the
# terminal AND it gets persisted to the log file for debugging.
exec > >(tee -a "$LOG_FILE") 2>&1

log "Logging to: $LOG_FILE"

# Detect Debian version
. /etc/os-release 2>/dev/null || die "Not a Debian-based system"
log "Detected: $PRETTY_NAME"

# ── 1. System packages ────────────────────────────────────────────────
log "Updating apt and installing base packages..."
apt-get update -qq

# Detect architecture for the UI bundle naming.
HOST_ARCH="$(uname -m)"
case "$HOST_ARCH" in
  x86_64)  UI_ARCH="x86-64" ;;
  aarch64) UI_ARCH="arm64" ;;
  *)       UI_ARCH="$HOST_ARCH" ;;
esac

apt-get install -y -qq curl git ca-certificates gnupg build-essential \
  postgresql postgresql-contrib \
  \
  cage \
  \
  libgtk-3-0 libglib2.0-0 libpango-1.0-0 libcairo2 libharfbuzz0b \
  libwayland-client0 libwayland-egl1 libegl1 libgl1 \
  libblkid1 liblzma5 libpulse0 \
  libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  fonts-noto-core >/dev/null
ok "Base packages installed (incl. cage + Flutter runtime libs)"

# ── 2. Node.js 22 LTS (via NodeSource) ────────────────────────────────
if ! command -v node &>/dev/null || [[ "$(node -v 2>/dev/null | cut -dv -f2 | cut -d. -f1)" -lt "$NODE_MAJOR" ]]; then
  log "Installing Node.js $NODE_MAJOR LTS..."
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash -
  apt-get install -y -qq nodejs >/dev/null
fi
ok "Node.js $(node -v), npm $(npm -v)"

# ── 3. PostgreSQL: create user + database ─────────────────────────────
log "Setting up PostgreSQL..."
sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASS}';"
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1 \
  || sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${DB_PASS}';" >/dev/null
systemctl enable --now postgresql
# On some Raspberry Pi OS images, postgresql doesn't auto-start after install.
systemctl is-active --quiet postgresql || systemctl start postgresql
ok "Database '${DB_NAME}' ready"

# ── 4. System user + directories ──────────────────────────────────────
if ! id "$SERVICE_USER" &>/dev/null; then
  log "Creating system user '$SERVICE_USER'..."
  useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"
fi
mkdir -p "$INSTALL_ROOT/versions" "$INSTALL_ROOT/releases"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$INSTALL_ROOT"

# ── 5. Download + install the first version ───────────────────────────
log "Fetching latest version from master..."
VERSION=$(curl -fsSL \
  "https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/VERSION.txt" 2>/dev/null \
  | tr -d '[:space:]' || echo "0.1.0")
log "Installing version $VERSION..."

VERSION_DIR="$INSTALL_ROOT/versions/$VERSION"
TMP_DIR=$(mktemp -d)
log "Downloading repo tarball..."
curl -fsSL "https://github.com/xibhuxan/hiluxOS/archive/refs/heads/master.tar.gz" \
  -o "$TMP_DIR/master.tar.gz"
log "Extracting to $VERSION_DIR..."
mkdir -p "$VERSION_DIR"
tar xzf "$TMP_DIR/master.tar.gz" -C "$VERSION_DIR" --strip-components=1
rm -rf "$TMP_DIR"

# ── 6. Backend: deps, build, prune ────────────────────────────────────
log "Installing backend dependencies (this takes a few minutes on a Pi)..."
cd "$VERSION_DIR/backend"
npm ci --no-audit --no-fund
ok "Dependencies installed"

log "Building backend (TypeScript → JavaScript)..."
npm run build
ok "Backend compiled → dist/main.js"

log "Generating Prisma client..."
npx prisma generate
ok "Prisma client generated"

# ── 7. .env file ──────────────────────────────────────────────────────
if [[ ! -f "$VERSION_DIR/backend/.env" ]]; then
  log "Creating .env..."
  cat > "$VERSION_DIR/backend/.env" <<EOF
PORT=3000
CORS_ORIGIN=*
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}?schema=public
RADIO_API_URL=https://de1.api.radio-browser.info
UPDATE_INSTALL_ROOT=${INSTALL_ROOT}
UPDATE_VERSION_URL=https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/VERSION.txt
UPDATE_TARBALL_URL=https://github.com/xibhuxan/hiluxOS/archive/refs/heads/master.tar.gz
EOF
fi

# ── 8. Database migrations ────────────────────────────────────────────
log "Running database migrations..."
npx prisma migrate deploy
ok "Database migrated"

# ── 8b. Prune dev dependencies (MUST be after build + prisma) ─────────
# prisma CLI is a devDependency, so we can only prune after migrate.
# The compiled dist/ + @prisma/client (runtime) are all we need to run.
log "Pruning dev dependencies..."
npm prune --omit=dev
ok "Dev dependencies pruned"

# ── 9. Symlink + ownership ────────────────────────────────────────────
ln -sfn "$VERSION_DIR" "$INSTALL_ROOT/current"
chown -R "$SERVICE_USER":"$SERVICE_USER" "$VERSION_DIR"
ok "current → $VERSION"

# ── 10. systemd service ───────────────────────────────────────────────
log "Installing systemd service..."
NODE_BIN="$(command -v node)"
[[ -n "$NODE_BIN" ]] || die "node binary not found in PATH"

cat > /etc/systemd/system/hiluxos-backend.service <<EOF
[Unit]
Description=hiluxOS backend API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${INSTALL_ROOT}/current/backend
EnvironmentFile=${INSTALL_ROOT}/current/backend/.env
ExecStart=${NODE_BIN} dist/main.js
Restart=on-failure
RestartSec=5
KillSignal=SIGINT
TimeoutStopSec=10
StartLimitIntervalSec=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hiluxos-backend
systemctl restart hiluxos-backend

# ── 11. Verify it started ─────────────────────────────────────────────
log "Waiting for backend to respond..."
for i in $(seq 1 15); do
  if curl -fsS "http://localhost:3000/api/health" >/dev/null 2>&1; then
    ok "Backend is live on http://localhost:3000"
    break
  fi
  [[ $i -eq 15 ]] && die "Backend did not start in time. Check: journalctl -u hiluxos-backend -e"
  sleep 2
done

# ── 12. UI: download Flutter bundle from GitHub Release ───────────────
UI_BUNDLE_NAME="hiluxos-ui-${UI_ARCH}.tar.gz"
UI_DIR="$INSTALL_ROOT/ui"
UI_BUNDLE_URL="https://github.com/xibhuxan/hiluxOS/releases/download/v${VERSION}/${UI_BUNDLE_NAME}"

log "Downloading UI bundle ($UI_ARCH) from GitHub Release v$VERSION..."
mkdir -p "$UI_DIR"
if curl -fsSL "$UI_BUNDLE_URL" -o "/tmp/$UI_BUNDLE_NAME"; then
  ok "UI bundle downloaded"
  tar xzf "/tmp/$UI_BUNDLE_NAME" -C "$UI_DIR" --strip-components=1
  rm -f "/tmp/$UI_BUNDLE_NAME"
  chmod +x "$UI_DIR/hiluxos"
  chown -R "$SERVICE_USER":"$SERVICE_USER" "$UI_DIR"

  # Verify the binary has all its shared libraries.
  if ldd "$UI_DIR/hiluxos" 2>/dev/null | grep -q "not found"; then
    log "⚠ UI binary is missing some shared libraries:"
    ldd "$UI_DIR/hiluxos" 2>/dev/null | grep "not found"
    die "Install the missing libraries and re-run, or rebuild the bundle for this OS/arch."
  fi
  ok "UI binary dependencies satisfied"
else
  log "⚠ UI bundle for $UI_ARCH not found at:"
  log "  $UI_BUNDLE_URL"
  log "  The backend is installed and running, but the UI (cage + Flutter) was skipped."
  log "  Build and upload the bundle with: scripts/release-ui.sh"
  log "  Continuing without UI service..."
fi

# ── 13. UI systemd service (cage kiosk) ───────────────────────────────
if [[ -x "$UI_DIR/hiluxos" ]]; then
  log "Installing UI systemd service (cage kiosk)..."

  # Cage runs as root to access /dev/dri directly (no logind session on a
  # headless box). It creates its own Wayland compositor and launches the
  # Flutter app fullscreen on the physical display (HDMI / DSI).
  cat > /etc/systemd/system/hiluxos-ui.service <<EOF
[Unit]
Description=hiluxOS UI (Cage Wayland kiosk + Flutter app)
After=hiluxos-backend.service
Wants=hiluxos-backend.service

[Service]
Type=simple
User=root
Environment=XDG_RUNTIME_DIR=/run/user/0
Environment=HOME=/root
# WLR_RENDERER=pixman = software rendering (works without GPU/3D accel,
# e.g. VirtualBox). On the Pi the VC4/V3D GPU works, so this is harmless
# to set everywhere — wlroots falls back to it only if EGL fails.
Environment=WLR_RENDERER=pixman
ExecStart=/usr/bin/cage -- ${UI_DIR}/hiluxos
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  # Ensure the runtime dir cage needs exists.
  mkdir -p /run/user/0
  chmod 700 /run/user/0

  systemctl daemon-reload
  systemctl enable hiluxos-ui
  systemctl start hiluxos-ui
  ok "UI service started (cage + Flutter on the physical display)"
fi

# ── 14. Cleanup ───────────────────────────────────────────────────────
apt-get clean

echo ""
echo -e "\033[1;32m═══════════════════════════════════════════════════════════════"
echo "  hiluxOS $VERSION installed successfully!"
echo "═══════════════════════════════════════════════════════════════\033[0m"
echo ""
echo "  Backend:    http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):3000"
echo "  Services:   systemctl status hiluxos-backend hiluxos-ui"
echo "  Logs:       journalctl -u hiluxos-backend -f"
echo "              journalctl -u hiluxos-ui -f"
echo "  Install:    $INSTALL_ROOT/current (v$VERSION)"
echo "  Install log: $LOG_FILE"
echo ""
if [[ -x "$UI_DIR/hiluxos" ]]; then
echo "  UI:         Cage Wayland kiosk running on the physical display"
else
echo "  UI:         Not installed (no bundle for $UI_ARCH in the release)"
fi
echo ""
echo "  Updates will happen automatically from the app (Settings → Updates)."
echo ""

# Make sure the log is flushed before we exit.
sync "$LOG_FILE" 2>/dev/null || true
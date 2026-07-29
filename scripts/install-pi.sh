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
apt-get install -y -qq curl git ca-certificates gnupg build-essential \
  postgresql postgresql-contrib >/dev/null
ok "Base packages installed"

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
npm ci --no-audit --no-fund 2>&1 | tail -1
log "Building backend (TypeScript → JavaScript)..."
npm run build 2>&1 | tail -1
log "Generating Prisma client..."
npx prisma generate 2>&1 | tail -1
log "Pruning dev dependencies..."
npm prune --omit=dev 2>&1 | tail -1
ok "Backend built"

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
npx prisma migrate deploy 2>&1 | tail -3
ok "Database migrated"

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

# ── 12. Cleanup ───────────────────────────────────────────────────────
apt-get clean

echo ""
echo -e "\033[1;32m═══════════════════════════════════════════════════════════════"
echo "  hiluxOS $VERSION installed successfully!"
echo "═══════════════════════════════════════════════════════════════\033[0m"
echo ""
echo "  Backend:    http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):3000"
echo "  Service:    systemctl status hiluxos-backend"
echo "  Logs:       journalctl -u hiluxos-backend -f"
echo "  Install:    $INSTALL_ROOT/current (v$VERSION)"
echo "  Install log: $LOG_FILE"
echo ""
echo "  Updates will happen automatically from the app (Settings → Updates)."
echo ""

# Make sure the log is flushed before we exit.
sync "$LOG_FILE" 2>/dev/null || true
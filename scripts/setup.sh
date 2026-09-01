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

echo "==> Installing udev rule for backlight permissions..."
sudo cp "$ROOT/scripts/99-backlight.rules" /etc/udev/rules.d/99-backlight.rules
sudo udevadm control --reload-rules
# Apply the rule immediately to the already-present backlight device(s),
# so brightness works right away without a reboot. We trigger both "add"
# and "change" actions: "add" runs on boot, but re-triggering an existing
# node sometimes needs "change" to force the RUN commands on modern udevd.
sudo udevadm trigger --subsystem-match=backlight --action=add
sudo udevadm trigger --subsystem-match=backlight --action=change
# Ensure the current user belongs to the video group (the rule grants
# write access to it). The membership only takes effect on next login.
if ! id -nG | tr ' ' '\n' | grep -qx video; then
  sudo usermod -aG video "$USER"
  echo "    ⚠ Added \$USER to 'video' group — log out and back in for it to take effect."
fi
# Show the resulting permissions so it's easy to confirm.
BL=$(ls /sys/class/backlight/*/brightness 2>/dev/null | head -1)
if [ -n "$BL" ]; then
  echo "    Backlight node: $BL"
  ls -la "$BL" | sed 's/^/      /'
else
  echo "    ⚠ No /sys/class/backlight/* device found on this host."
fi
echo ""

echo "==> Setup complete."
echo "    Start everything with: scripts/dev.sh"
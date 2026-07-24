# HiluxOS — Automotive Infotainment System

An AI-developed, human-supervised in-vehicle infotainment system. Backend in
Node.js (NestJS + Prisma + PostgreSQL), frontend in Flutter, infrastructure in
Docker. See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for the full design.

```
┌─────────────┐   REST + WebSocket   ┌──────────────────┐   ┌────────────┐
│  Flutter     │ ◄──────────────────► │  NestJS backend  │ ─► │ PostgreSQL │
│  (app/)      │                      │  (backend/)      │   │ (Docker)   │
└─────────────┘                      └──────────────────┘   └────────────┘
```

Flutter plays audio directly (`audioplayers`); the backend only returns stream
URLs, metadata, favorites and history.

## Repository layout

```
app/        Flutter frontend (feature-first)
backend/    NestJS + Prisma backend
docker/     Docker Compose for PostgreSQL
scripts/    setup / dev / run-app / validate
docs/       Architecture Decision Records
ARCHITECTURE.md   source of truth for the design
```

## Prerequisites

- Node 22 LTS
- Flutter stable
- Docker Engine + Compose v2
- (Linux desktop only) GStreamer dev packages for `audioplayers`:
  ```
  sudo dnf install -y gstreamer1-devel gstreamer1-plugins-base-devel \
    gstreamer1-plugins-good gstreamer1-plugins-good-extras \
    gstreamer1-plugins-bad-free gstreamer1-plugins-bad-free-devel \
    gstreamer1-plugins-ugly-free
  ```

## Quick start

```bash
# 1. One-time setup: start PostgreSQL, install backend deps, run migration + seed
scripts/setup.sh

# 2. Start the backend (watch mode on :3000)
scripts/dev.sh

# 3. In another terminal, run the Flutter app on Linux desktop
scripts/run-app.sh
```

By default the app reaches the backend at `http://localhost:3000`. To point it
elsewhere (e.g. the Pi), override at build time:

```bash
flutter run -d linux \
  --dart-define=APP_API_URL=http://192.168.1.10:3000 \
  --dart-define=APP_WS_URL=ws://192.168.1.10:3000/events
```

## Configuration

All configuration comes from environment variables (never hardcoded). See
[`.env.example`](./.env.example) for the full list. The backend reads
`backend/.env`; copy from `.env.example`.

## API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/health` | Liveness + DB check |
| GET | `/api/system/info` | Static system identity |
| GET | `/api/system/resources` | Live CPU/RAM/temperature |
| GET | `/api/settings` | All settings as `{ key: value }` |
| PUT | `/api/settings/:key` | Upsert a setting |
| GET | `/api/radio/stations/search?q=` | Search Radio Browser |
| GET | `/api/radio/favorites` | Favorite stations |
| POST | `/api/radio/favorites` | Add a favorite |
| GET | `/api/radio/history` | Playback history |
| WS | `/events` | Real-time event stream |

## Status

This branch (`clean/port-bootstrap`) is the active, from-scratch port. The
functional milestone covers: health, system, settings, radio (search +
favorites + history + playback), and a feature-first Flutter app with splash,
dashboard, radio (with spectrum visualizer), system and settings screens.

Deferred: GPIO, power, OBD-II, media, Bluetooth, camera, voice, navigation,
and the Invidious/YouTube proxy.
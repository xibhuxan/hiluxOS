# HiluxOS — Automotive Infotainment System

An AI-developed, human-supervised in-vehicle infotainment system. Backend in
Node.js (NestJS + Prisma + PostgreSQL), frontend in Flutter, infrastructure in
Docker. See [`ARCHITECTURE.md`](./ARCHITECTURE.md) for the technical design and
[`docs/ARCHITECTURE-FUNCTIONAL.md`](./docs/ARCHITECTURE-FUNCTIONAL.md) for the
functional/product architecture (philosophy, UI types, development levels).

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
docs/       all project documentation (see map below)
```

### Documentation map

| Document | What it covers |
|----------|----------------|
| [`ARCHITECTURE.md`](./ARCHITECTURE.md) | Technical design (source of truth) |
| [`docs/ARCHITECTURE-FUNCTIONAL.md`](./docs/ARCHITECTURE-FUNCTIONAL.md) | Functional/product design (source of truth) |
| [`docs/USAGE.md`](./docs/USAGE.md) | Dev workflow, screens guide, full API reference |
| [`docs/STATUS.md`](./docs/STATUS.md) | Live project status and next steps |
| [`docs/RELEASES.md`](./docs/RELEASES.md) | Versioning, releases, OTA, deployment |
| [`docs/adr-*.md`](./docs) | Architecture Decision Records |
| [`docs/ROADMAP-MEDIA.md`](./docs/ROADMAP-MEDIA.md) | Media roadmap (parked video analysis) |
| [`docs/NOTES-VEHICLE-UI.md`](./docs/NOTES-VEHICLE-UI.md) | Working notes — next Vehicle UI session |

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

The backend serves everything under `/api` (plus a plain WebSocket at `/events`).
Highlights:

- **System** — health, info, live resources, audio, brightness, Wi-Fi/Bluetooth
- **Radio & Media** — Radio Browser search, favorites, history, local library
  with configurable folders, streaming with Range, album art, spectrum
- **Vehicle / Power / GPIO** — HAL with swappable drivers (`HAL_*` env vars)
- **Settings, Tasks, Notifications, Event log, OTA updates**

Full endpoint reference: [`docs/USAGE.md`](./docs/USAGE.md#4-referencia-api).

## Status

See [`docs/STATUS.md`](./docs/STATUS.md) for the live project status, what works
and the next steps.
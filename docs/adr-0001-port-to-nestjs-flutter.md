# ADR-0001: Port to NestJS + Flutter

Date: 2026-07-24
Status: Accepted

## Context

hiluxOS originated as a Python monolith (PySide6 + QML). The project is now
developed primarily by AI agents under human supervision, which favors a
simpler, more conventional stack with strong tooling.

## Decision

Replace the Python/QML monolith with:

- **Backend**: Node.js + NestJS + Prisma ORM, running on the host.
- **Frontend**: Flutter, running on the host (Linux desktop).
- **Database**: PostgreSQL, running in Docker.

Only infrastructure services run in Docker. Application code runs on the host
during development.

## Consequences

- The original `EventBus` is replaced by a NestJS WebSocket gateway (`/events`).
- App discovery by filesystem is replaced by declarative NestJS modules.
- Audio playback moves to Flutter (`just_audio`); the backend only returns
  stream URLs and metadata, so the spectrum visualizer stays latency-free.
- Hardware interaction (GPIO, power, OBD-II) becomes backend services with a
  mock-first development path toggled by environment variables.

## Out of scope for the initial functional milestone

GPIO, power, OBD-II, media, Bluetooth, camera, voice, navigation, and the
Invidious/YouTube proxy. These are deferred to later milestones.
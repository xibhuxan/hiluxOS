# hiluxOS — Flutter frontend

Flutter frontend for the hiluxOS in-vehicle infotainment system. It is
**exclusively a UI**: it renders state and sends actions to the backend over
REST + WebSocket. It never contains business logic or accesses hardware
directly.

See [`../ARCHITECTURE.md`](../ARCHITECTURE.md) for the technical architecture
and [`../docs/ARCHITECTURE-FUNCTIONAL.md`](../docs/ARCHITECTURE-FUNCTIONAL.md)
for the functional/product design (UI types, element types, development
levels).

## Run

```bash
# From the repo root (backend must be running on :3000)
../scripts/run-app.sh        # flutter run -d linux

# Or point at a remote backend (e.g. the Raspberry Pi)
flutter run -d linux \
  --dart-define=APP_API_URL=http://192.168.1.10:3000 \
  --dart-define=APP_WS_URL=ws://192.168.1.10:3000/events
```

## Structure

Feature-first. See [`../ARCHITECTURE.md`](../ARCHITECTURE.md) "Flutter
Architecture" for details.

```
lib/
  core/       API client, theme, shared widgets
  features/   splash, home, radio, system_info, settings, tasks
  layout/     app shell, navigation, status panel
  shared/     shared models
```

## Analyze

```bash
flutter analyze
```
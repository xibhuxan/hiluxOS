# Estado del proyecto — hiluxOS

Última actualización: 2026-07-27 (Brightness real + hot reload)

## Stack y ramas

- **Stack**: NestJS + Prisma + PostgreSQL (backend, host) · Flutter (app, host) · PostgreSQL en Docker.
- **Ramas**:
  - `master` → `51c3bad` (4 commits por delante de `origin/master`, **sin push**).
  - `dev` → `4c8de70` (mergeado desde `feature/ui-polish`).
  - `feature/ui-polish` → `4c8de70` (ya mergeada a `dev`, se puede eliminar).
- **Sin push** a remoto en ninguna rama. Cuando se quiera publicar: `git push origin master` (fast-forward) + `git push -u origin dev`.
- Recordatorios del entorno: Flutter en `/home/xibhu/flutter/bin/flutter` y Docker/postgres/conexiones a localhost se ejecutan **con sandbox desactivado**.

## Qué funciona (verificado E2E en Linux desktop)

### Backend (`backend/`)
- `GET /api/health` — liveness + BD.
- `GET /api/system/info`, `/api/system/resources` (CPU/RAM/temp/**disco**/uptime/load).
- `GET|PUT /api/system/audio` — volumen real del SO (wpctl, amixer fallback) + mute.
- `GET|PUT /api/system/network` — WiFi real (nmcli) + toggle.
- `GET|PUT /api/system/bluetooth` — Bluetooth real (bluetoothctl) + toggle.
- **`GET|PUT /api/system/brightness`** — brillo real vía sysfs (lectura/escritura en `/sys/class/backlight/intel_backlight/brightness`).
- `GET|PUT|DELETE /api/settings` — CRUD de ajustes.
- `GET /api/radio/stations/search`, `/radio/favorites` (GET/POST/DELETE), `/radio/history`, `/radio/stream/:id` — Radio Browser API.
- `GET /api/tasks` (+ POST/PUT/DELETE) — módulo Pendientes, con seed (ITV, aceite, update, backup).
- WebSocket `/events` (gateway).
- Migraciones Prisma aplicadas; seed ejecutado.

### Flutter (`app/`)
- Splash animado (logo +50%, glow pulsante, barra animada, transición).
- Shell: panel superior fijo opaco con **volumen a la izquierda** (slider 180px táctil, funcional), reloj, Home, Apps; cajón de apps (end drawer) con tiles.
- **Quick Panel**: overlay deslizante desde el panel superior con toggles WiFi/BT, sliders volumen/brillo, indicadores de Internet y Backend. Cierra tocando fuera.
- Home: barra contextual + 4 cards (Estado actual, Sistema, Vehículo, Pendientes) en grid 2×2 sin scroll.
- Pantallas: Radio (búsqueda, favoritos, historial, playback + visualizador), System, Settings — cableadas al backend.
- `flutter analyze` sin errores.

## Pendiente / siguientes pasos

### ⚠️ Brightness — permisos (pendiente de aplicar)
El backend ya tiene el endpoint `/system/brightness` y el slider del Quick Panel lo usa. **Pero** `/sys/class/backlight/intel_backlight/brightness` es de `root:root` con permisos `-rw-r--r--`, así que el backend (corre como `xibhu`) no puede escribir. Ya está creada la regla udev (`scripts/99-backlight.rules`) y el `setup.sh` actualizado, pero **falta aplicar los permisos manualmente** tras el reinicio:

```bash
# 1. Asegurar que tu usuario está en el grupo video
sudo usermod -aG video $USER
# 2. Dar permisos ahora mismo (sin reiniciar)
sudo chmod g+w /sys/class/backlight/intel_backlight/brightness
sudo chown :video /sys/class/backlight/intel_backlight/brightness
# 3. Verificar
ls -la /sys/class/backlight/intel_backlight/brightness
#    Debe mostrar: -rw-rw-r--. 1 root video ...
```

Después de eso, el slider de brillo en el Quick Panel debería escribir y persistir correctamente.

### Inmediato
- ✅ **Quick Panel**: overlay deslizante con toggles WiFi/BT, sliders volumen/brillo, indicadores. Cierra tocando fuera.
- ✅ **Brightness real**: endpoint backend + provider Flutter conectado a `/system/brightness`.
- ✅ **Hot reload**: `scripts/run-app.sh` ahora muestra banner y usa `--debug`.
- Decidir si subir a remoto (`master` va con fast-forward).

### UI/UX (siguiente pasada)
- Pulido interno de las apps: **Radio** (shimmer al buscar, entrada animada de ítems, "pop" del icono de favorito, now-playing más vistoso), **System**, **Settings** (cabeceras, feedback).
- La card **Sistema** tiene una celda vacía (8º hueco): rellenar con algo útil (p. ej. estado de red global, versión, o un mini gauges) o redistribuir.
- **Configuración de WiFi/Bluetooth** en una pantalla aparte (los toggles reales viven en los providers `networkProvider`/`bluetoothProvider`, hoy solo informativos en la card Sistema).
- **Pendientes**: hoy solo listar + completar; falta **crear/editar** tareas desde la UI (el backend ya soporta POST/PUT/DELETE).
- Recordatorios de mantenimiento / prioridad de tareas (backend tiene `priority`, no se ordena en UI).

### Backend (futuro, fuera del MVP)
- **HAL**: módulos GPIO, Power, Vehicle/OBD-II (mock-first, toggle por env). La card Vehículo hoy muestra "No conectado".
- Media (archivos locales, metadatos), Bluetooth pairing/llamadas, Cámara (marcha atrás), Voz (servicio Python), Navegación/GPS.
- Proxy YouTube/Invidious (`POST /youtube/resolve`).
- Salud energética de la Pi: undervoltage/throttle (leer `/sys` o `vcgencmd`) — diferenciador.

### Infra / despliegue
- Automatizar despliegue a la Raspberry Pi (un solo comando).
- CI/CD, tests (unitarios backend, widget tests Flutter).

## Cómo arrancar (resumen)
```bash
scripts/setup.sh    # Postgres + deps + migración + seed (1ª vez)
scripts/dev.sh      # backend en :3000 (watch)
scripts/run-app.sh  # flutter run -d linux (otra terminal, hot reload con r)
```
Más detalle en `docs/USAGE.md`. Diseño fuente de verdad: `ARCHITECTURE.md`.

# Estado del proyecto — hiluxOS

Última actualización: 2026-08-11 (Fase 1 — tests unitarios + e2e backend, widget tests Flutter)

## Stack y ramas

- **Stack**: NestJS 11 + Prisma 6 + PostgreSQL 17 (backend, host) · Flutter stable (app, host) · PostgreSQL en Docker.
- **Versión**: `0.1.0` (`VERSION.txt`).
- **Ramas** (todas sincronizadas con `origin`, HEAD `3d75843`):
  - `master` → `2c417f7` — rama de release.
  - `dev` → `2c417f7` — integración.
  - `feature/develop` (activa) → `3d75843` — desarrollo en curso.
- Working tree limpio. Todo publicado en el remoto.
- Recordatorios del entorno: Flutter en `/home/xibhu/flutter/bin/flutter` y Docker/postgres/conexiones a localhost se ejecutan **con sandbox desactivado**.

## Estado de compilación

- Backend: `tsc --noEmit` → **0 errores**.
- Flutter: `flutter analyze` → **0 issues** (lints `unnecessary_underscores` corregidos en Fase 0).
- **Tests**:
  - Backend unitarios (Jest): **32 tests** — `health.service`, `settings.service`, `tasks.service`, `radio.service` (mock Prisma + fetch global).
  - Backend e2e (Supertest): **28 tests** — `health`, `tasks`, `settings`, `radio` controllers con AppModule completa, mock Prisma + EventsGateway + fetch.
  - Flutter: **11 tests** — `splash_screen` (render + barra de progreso), `home_screen` (4 mensajes contextuales con providers mockeados), `quick_panel` (render tiles + callbacks open/close), `widget_test` (sanity checks).
  - **Total: 71 tests** (32 unit + 28 e2e + 11 widget). Comando e2e: `npm run test:e2e`.

## Qué funciona (verificado E2E en Linux desktop)

### Backend (`backend/`)
- `GET /api/health` — liveness + BD.
- `GET /api/system/info`, `/api/system/resources` (CPU/RAM/temp/**disco**/uptime/load).
- `GET|PUT /api/system/audio` — volumen real del SO (wpctl, amixer fallback) + mute.
- `GET|PUT /api/system/network` — WiFi real (nmcli) + toggle.
- `GET /api/system/network/wifi/scan`, `POST .../wifi/connect` (ssid+password), `POST .../wifi/disconnect`, `POST .../wifi/forget` — escaneo, conexión (con contraseña), desconexión y olvido de redes WiFi.
- `GET|PUT /api/system/bluetooth` — Bluetooth real (bluetoothctl) + toggle.
- `GET /api/system/network/bluetooth/scan`, `POST .../bluetooth/pair` (mac+pin opcional), `POST .../bluetooth/connect`, `POST .../bluetooth/disconnect`, `POST .../bluetooth/remove` — escaneo, emparejamiento (con PIN vía stdin), conexión, desconexión y olvido de dispositivos BT. `SystemService` refactorizado con `CommandRunner` inyectable (mockeable en tests).
- `GET|PUT /api/system/brightness` — brillo real vía sysfs (lectura/escritura en `/sys/class/backlight/intel_backlight/brightness`).
- `GET|PUT|DELETE /api/settings` — CRUD de ajustes.
- `GET /api/radio/stations/search`, `/radio/favorites` (GET/POST/DELETE), `/radio/history`, `/radio/stream/:id` — Radio Browser API.
- `GET /api/tasks` (+ POST/PUT/DELETE) — módulo Pendientes, con seed (ITV, aceite, update, backup).
- `GET /api/notifications` — sistema de notificaciones (creación, listado, marcar leída = borrar).
- `GET /api/event-log` — registro de eventos del sistema.
- WebSocket `/events` (gateway, `ws` en lugar de Socket.IO para compatibilidad con Flutter).
- **Sistema OTA** (`/api/updates`): deploy blue-green, rollback automático, comprobación por `VERSION.txt`, descarga del tarball master, y **actualización del bundle UI** desde GitHub Releases + reinicio de cage. Endpoints de estado/verificación/aplicación.
- Migraciones Prisma aplicadas; seed ejecutado.

### Flutter (`app/`)
- Splash animado (logo +50%, glow pulsante, barra animada, transición).
- Shell: panel superior fijo opaco con **volumen a la izquierda** (slider 180px táctil, funcional), reloj, Home, Apps; cajón de apps (end drawer) con tiles.
- **Quick Panel**: overlay deslizante desde el panel superior con toggles WiFi/BT, sliders volumen/brillo, indicadores de Internet y Backend. Cierra tocando fuera.
- Home: barra contextual + 4 cards (Estado actual, Sistema, Vehículo, Pendientes) en grid 2×2 sin scroll.
- Pantallas: Radio (búsqueda, favoritos, historial, playback + visualizador), System, Settings — cableadas al backend.
- **Settings → Wi-Fi & Bluetooth**: secciones dedicadas en la pantalla de Ajustes con toggle de radio, escaneo, lista de redes/dispositivos, diálogo de contraseña WiFi y diálogo de PIN Bluetooth.
- **Teclado en pantalla** (`virtual_keypad`): teclado virtual pure-Dart integrado en el `AppShell` (modo standalone, se oculta sin foco). Cualquier `TextField`/`TextFormField` del app (incluido `TaskDialog`, contraseña WiFi, PIN BT) obtiene teclado táctil automáticamente — necesario porque la RPi+Cage/Wayland no tiene IME del sistema. `initializeKeyboardLayouts()` en `main()`.
- **Notificaciones**: panel + toast, provider conectado al backend.
- **Updates**: sección de actualización OTA en la UI.
- `flutter analyze` sin errores.

### Infra / despliegue
- `scripts/install-pi.sh` — instalador para Raspberry Pi OS (Debian-minimal): PostgreSQL auto-start, detección de node, build, prune de devDeps, salida a `/var/log/hiluxos-install.log`.
- `scripts/release-ui.sh` — publica el bundle Flutter como GitHub Release para que el OTA lo descargue.
- Cage kiosk mode (sin decoraciones de ventana), backend `seatd` habilitado para input devices.
- Despliegue a Pi no está totalmente automatizado a un solo comando todavía.

## Pendiente / siguientes pasos

### ⚠️ Brightness — permisos (pendiente de aplicar en el SO)
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

### Fase 1 — Protección (tests) ✅
- **Tests unitarios backend (Jest)**: `health`, `settings`, `tasks`, `radio`, `system` (54 tests, mock Prisma + `CommandRunner` fake para nmcli/bluetoothctl). ✅
- **Tests e2e backend (Supertest)**: `health`, `tasks`, `settings`, `radio`, `system` controllers (41 tests, AppModule completa con Prisma + EventsGateway + SystemService mockeados). ✅
- **Widget tests Flutter**: `splash`, `home`, `quick_panel`, `pendientes_card`, `network_settings` (22 tests, providers mockeados con fakes que evitan red/timers). ✅
- **Siguiente**: ampliar cobertura — más pantallas Flutter (radio, system), controllers restantes (notifications, event-log, updates).

### Fase 2 — Cerrar lo casi-terminado
- **Permisos de brightness**: automatizar el paso de `chmod`/`chown` (regla udev aplicable sin paso manual).
- ~~**Pantalla de configuración WiFi/Bluetooth**: los providers ya existen y funcionan, hoy solo informativos en la card Sistema. Conectarlos a una pantalla aparte.~~ ✅ — secciones `WifiSection` y `BluetoothSection` dentro de Settings: toggle, escaneo, lista de redes/dispositivos, diálogo de contraseña WiFi (`WifiPasswordDialog`) y diálogo de PIN BT (`BtPinDialog`). Backend con scan/connect/disconnect/forget/pair/remove vía nmcli/bluetoothctl. Teclado en pantalla `virtual_keypad` para meter texto en la RPi táctil.
- ~~**CRUD de Pendientes desde la UI**: el backend ya soporta POST/PUT/DELETE; la UI solo lista/completa. Rellenar crear/editar.~~ ✅ — botón `+` para crear, tap en título para editar, icono papelera para borrar (con confirmación). `TasksService` ahora lanza `NotFoundException` (404) en Prisma `P2025` en vez de propagar 500.
- ~~Ordenar pendientes por prioridad (el backend tiene `priority`, no se usa en UI).~~ ✅ — el backend ya ordena por `priority desc` en `findAll()`; la UI ahora muestra la prioridad y permite editarla con un slider 0–5 en el diálogo.

### Fase 3 — Diferenciador (HAL)
- **HAL mock-first**: módulos `Vehicle`/`Power`/`GPIO` con interfaz + implementación mock (toggle por env), siguiendo la arquitectura de sustitución de `ARCHITECTURE.md`. Desbloquea la card "Vehículo" (hoy "No conectado").
- **Salud energética de la Pi**: undervoltage/throttle leyendo `/sys` o `vcgencmd`.

### Fase 4 — Pulido y producto
- Pulido UI de **Radio** (shimmer en búsqueda, entrada animada de ítems, "pop" de favorito, now-playing vistoso), **System**, **Settings** (cabeceras, feedback).
- Rellenar celda vacía de la card **Sistema** (estado de red global / versión / mini-gauges).
- **CI/CD** (GitHub Actions): build backend + `tsc`, `flutter analyze`, tests.
- Media (archivos locales, metadatos), Bluetooth pairing/llamadas, Cámara (marcha atrás), Voz (servicio Python), Navegación/GPS.
- Proxy YouTube/Invidious (`POST /youtube/resolve`).

## Cómo arrancar (resumen)
```bash
scripts/setup.sh    # Postgres + deps + migración + seed (1ª vez)
scripts/dev.sh      # backend en :3000 (watch)
scripts/run-app.sh  # flutter run -d linux (otra terminal, hot reload con r)
```
Más detalle en `docs/USAGE.md`. Diseño fuente de verdad: `ARCHITECTURE.md`.

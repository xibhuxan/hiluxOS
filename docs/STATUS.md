# Estado del proyecto — hiluxOS

Última actualización: 2026-09-05 (pulido Media: portadas/album art + paneles plegables; títulos in-screen fuera)

## Stack y ramas

- **Stack**: NestJS 11 + Prisma 6 + PostgreSQL 17 (backend, host) · Flutter stable (app, host) · PostgreSQL en Docker.
- **Versión**: `0.1.0` (`VERSION.txt`).
- **Ramas** (todas sincronizadas con `origin`, HEAD `422620f`):
  - `master` → `2c417f7` — rama de release.
  - `dev` → `2c417f7` — integración.
  - `feature/develop` (activa) → `422620f` — desarrollo en curso.
- Working tree limpio. Todo publicado en el remoto.
- Recordatorios del entorno: Flutter en `/home/xibhu/flutter/bin/flutter` y Docker/postgres/conexiones a localhost se ejecutan **con sandbox desactivado**.

## Estado de compilación

- Backend: `tsc --noEmit` → **0 errores**.
- Flutter: `flutter analyze` → **0 issues** (lints `unnecessary_underscores` corregidos en Fase 0).
- **Tests**:
  - Backend unitarios (Jest): **90 tests** — `health.service`, `settings.service`, `tasks.service`, `radio.service`, `system.service`, `notifications.service`, `event-log.service`, `media-library.service` (mock Prisma + `CommandRunner` fake; `fs` mockeado para brightness y media scan), `media-art.service` (portadas: cover de carpeta, extracción ffmpeg con cache + marcador negativo).
  - Backend e2e (Supertest): **69 tests** — `health`, `tasks`, `settings`, `radio`, `system`, `notifications`, `event-log`, `media` controllers con AppModule completa, mock Prisma + EventsGateway + fetch. El de media incluye art con ffmpeg real (MEDIA_DIR de usar-y-tirar en tmp).
  - Flutter: **53 tests** — `splash_screen`, `home_screen`, `quick_panel`, `pendientes_card`, `network_settings`, `radio_stop_resume` (+sentinel), `visualizer_style`, `media_provider` (+cola/shuffle), `media_screen` (+árbol de carpetas, +chevrons de paneles), `shell_title`, `widget_test` (providers mockeados con fakes que evitan red/timers).
  - **Total: 212 tests** (90 unit + 69 e2e + 53 Flutter). Comando e2e: `npm run test:e2e`.

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
- `GET /api/radio/stations/search`, `/radio/favorites` (GET/POST/DELETE), `/radio/history`, `/radio/stream/:id` — Radio Browser API. **Fix 2026-09-01**: favoritos e historial persistían mal por 3 bugs encadenados — (1) `Station.toJson()` enviaba `id` → 400 `forbidNonWhitelisted`; (2)+(3) `upsert` Prisma 6.x con `update: {}` vacío enrutaba a create → 500 unique constraint. Los upserts ahora llevan `update` no vacío (lección aplicable a todo Prisma 6.x del proyecto).
- `GET /api/tasks` (+ POST/PUT/DELETE) — módulo Pendientes, con seed (ITV, aceite, update, backup).
- `GET /api/notifications` — sistema de notificaciones (creación, listado, marcar leída = borrar).
- `GET /api/event-log` — registro de eventos del sistema.
- WebSocket `/events` (gateway, `ws` en lugar de Socket.IO para compatibilidad con Flutter).
- **Sistema OTA** (`/api/updates`): deploy blue-green, rollback automático, comprobación por `VERSION.txt`, descarga del tarball master, y **actualización del bundle UI** desde GitHub Releases + reinicio de cage. Endpoints de estado/verificación/aplicación.
- Migraciones Prisma aplicadas; seed ejecutado.

### Flutter (`app/`)
- Splash animado (logo +50%, glow pulsante, barra animada, transición).
- Radio: búsqueda Radio Browser, favoritos, historial, playback (`audioplayers`) y **visualizador de espectro** con ring buffer + 15 estilos (commit 9644ac3).
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

### Fase 1 — Protección (tests) ✅
- **Tests unitarios backend (Jest)**: `health`, `settings`, `tasks`, `radio`, `system` (58 tests, mock Prisma + `CommandRunner` fake para nmcli/bluetoothctl; `fs` mockeado para brightness). ✅
- **Tests e2e backend (Supertest)**: `health`, `tasks`, `settings`, `radio`, `system` controllers (41 tests, AppModule completa con Prisma + EventsGateway + SystemService mockeados). ✅
- **Widget tests Flutter**: `splash`, `home`, `quick_panel`, `pendientes_card`, `network_settings` (22 tests, providers mockeados con fakes que evitan red/timers). ✅
- **Total: 121 tests** (58 unit + 41 e2e + 22 widget).
- **Siguiente**: ampliar cobertura — más pantallas Flutter (radio, system), controllers restantes (notifications, event-log, updates).

### Fase 2 — Cerrar lo casi-terminado
- ~~**Permisos de brightness**: automatizar el paso de `chmod`/`chown` (regla udev aplicable sin paso manual).~~ ✅ — regla udev genérica (`SUBSYSTEM=="backlight"`, sin filtrar por `KERNEL`) que cubre `intel_backlight` y `rpi_backlight`; `setup.sh` ahora dispara `udevadm trigger` tras instalarla para que se aplique sin reiniciar y muestra los permisos resultantes. Backend refactorizado: `backlightDir` auto-detecta el primer `/sys/class/backlight/*` (no más hardcodeo de `intel_backlight`), cacheado. 4 tests nuevos cubren lectura, escritura con path dinámico y caso sin backlight.
- ~~**Pantalla de configuración WiFi/Bluetooth**: los providers ya existen y funcionan, hoy solo informativos en la card Sistema. Conectarlos a una pantalla aparte.~~ ✅ — secciones `WifiSection` y `BluetoothSection` dentro de Settings: toggle, escaneo, lista de redes/dispositivos, diálogo de contraseña WiFi (`WifiPasswordDialog`) y diálogo de PIN BT (`BtPinDialog`). Backend con scan/connect/disconnect/forget/pair/remove vía nmcli/bluetoothctl. Teclado en pantalla `virtual_keypad` para meter texto en la RPi táctil.
- ~~**CRUD de Pendientes desde la UI**: el backend ya soporta POST/PUT/DELETE; la UI solo lista/completa. Rellenar crear/editar.~~ ✅ — botón `+` para crear, tap en título para editar, icono papelera para borrar (con confirmación). `TasksService` ahora lanza `NotFoundException` (404) en Prisma `P2025` en vez de propagar 500.
- ~~Ordenar pendientes por prioridad (el backend tiene `priority`, no se usa en UI).~~ ✅ — el backend ya ordena por `priority desc` en `findAll()`; la UI ahora muestra la prioridad y permite editarla con un slider 0–5 en el diálogo.

### Fase 3 — Diferenciador (HAL)
- **HAL mock-first**: módulos `Vehicle`/`Power`/`GPIO` con interfaz + implementación mock (toggle por env), siguiendo la arquitectura de sustitución de `ARCHITECTURE.md`. Desbloquea la card "Vehículo" (hoy "No conectado"). **Update 2026-09-01 (ADR-0002)**: el coche no tiene OBD-II — el driver real será `ESP32VehicleService` (centralita paralela ESP32/Arduino conectada por WiFi/serial). El HAL mock-first no cambia y puede construirse sin esperar al hardware.
- **Salud energética de la Pi**: undervoltage/throttle leyendo `/sys` o `vcgencmd`.

### Fase 4 — Pulido y producto
- ~~**Media (archivos locales, metadatos)**~~ ✅ 2026-09-04, pulido 2026-09-05 — hecho: modelo `Track` (con `relPath`) + `MediaLibraryService` (escaneo incremental ffprobe, `MEDIA_DIR`) + `/media/tracks|library/scan|stream/:id (Range)|tracks/:id/play` + pantalla Flutter `/media` (biblioteca con búsqueda, reescaneo, **árbol de carpetas lateral**, **cola** con prev/next/auto-advance y **shuffle**). Reproduce vía el `AudioPlayerService` compartido con radio. La barra superior muestra `Media — <canción>` (y `Radio — <emisora>`); los títulos in-screen de Media y Radio se quitaron (solo barra superior). **Portadas/album art** ✅: `GET /media/tracks/:id/art` — cover de carpeta (cover.jpg…) o arte embebido extraído con ffmpeg al vuelo y cacheado en `MEDIA_DIR/.hiluxos-art` (marcador `.noart` de 7 días para no relanzar ffmpeg); la UI lo muestra como protagonista en now-playing y como miniatura en las filas. **Paneles plegables** ✅: chevrons en la fila de controles pliegan el raíl de carpetas y la biblioteca (patrón AnimatedContainer de Radio). Fix: resume tras completar pista re-carga la fuente (el play grande ya responde).
- Pulido UI de **Radio** (shimmer en búsqueda, entrada animada de ítems, "pop" de favorito, now-playing vistoso), **System**, **Settings** (cabeceras, feedback).
- Rellenar celda vacía de la card **Sistema** (estado de red global / versión / mini-gauges).
- **CI/CD** (GitHub Actions): build backend + `tsc`, `flutter analyze`, tests.
- Proxy YouTube/Invidious (`POST /youtube/resolve`).

## Cómo arrancar (resumen)
```bash
scripts/setup.sh    # Postgres + deps + migración + seed (1ª vez)
scripts/dev.sh      # backend en :3000 (watch)
scripts/run-app.sh  # flutter run -d linux (otra terminal, hot reload con r)
```
Más detalle en `docs/USAGE.md`. Diseño fuente de verdad: `ARCHITECTURE.md`.

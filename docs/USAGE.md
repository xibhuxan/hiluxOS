# Cómo usar hiluxOS

Guía práctica para correr el sistema en desarrollo (Fedora / Linux desktop).
El stack: **Flutter** (`app/`) + **NestJS** (`backend/`) + **PostgreSQL** (Docker).

Prerrequisitos e instalación de dependencias: ver el
[README](../README.md#prerequisites). La configuración va por variables de
entorno (nunca hardcodeada): ver [`.env.example`](../.env.example); el backend
lee `backend/.env`.

---

## 1) Arranque

En un terminal — **infra + backend**:

```bash
scripts/setup.sh    # Postgres + dependencias + migración + seed (solo la 1ª vez)
scripts/dev.sh      # backend en http://localhost:3000 (modo watch)
```

En **otro terminal** — la app:

```bash
scripts/run-app.sh  # = flutter run -d linux
```

Arranca Splash → Home. La navegación es el **panel superior fijo** (volumen a
la izquierda, reloj, Home y Apps) más el **cajón de apps** (botón Apps): tiles
de Radio, Vehículo, System, Settings y Media (Bluetooth, Camera y Voice
deshabilitados por ahora). El Quick Panel se desliza desde el panel superior
(toggles WiFi/BT, volumen/brillo, indicadores).

### Apuntar la app a la Raspberry Pi (producción)

```bash
flutter run -d linux \
  --dart-define=APP_API_URL=http://192.168.1.10:3000 \
  --dart-define=APP_WS_URL=ws://192.168.1.10:3000/events
```

---

## 2) Qué hacer en cada pantalla

- **Home** (`/`) — 4 tarjetas fijas: Estado actual, Sistema (con versión y
  hint de actualización OTA), Vehículo (telemetría + chips de estado, se
  degrada a «No conectado») y Pendientes (crear/editar/completar/borrar con
  prioridad).
- **Radio** (`/radio`) — pestañas Search (Radio Browser: escribe `bbc`,
  `jazz`…, ♥ guarda en favoritos — persiste en Postgres), Favorites e
  History. Playback con visualizador de espectro (15 estilos) y botón ⛶ a
  pantalla completa (tap en cualquier punto para salir).
- **Media** (`/media`) — biblioteca de música local con búsqueda, raíl de
  carpetas configurables (＋ Añadir, ⚠️ no disponible, quitar con
  confirmación), cola con prev/next/auto-advance y shuffle, portadas, y
  selector de vista now-playing (álbum con efecto vinilo o espectro). El
  escaneo usa ffprobe contra las carpetas configuradas.
- **Vehículo** (`/vehicle`) — dos modos que comparten un solo poll: **Control**
  (arranque START/STOP, luces, intermitentes one-shot, cierre y alarma,
  ventanillas por unidad, puertas) y **Dashboard** (velocímetro/tacómetro
  pintados, métricas, testigos del cuadro, pantalla completa ⛶). En dev va
  contra el driver mock (`HAL_VEHICLE=mock`).
- **System** (`/system`) — identidad, recursos en vivo (CPU/RAM/disco/
  temperatura/energía de la Pi) y registro de eventos. Tira hacia abajo para
  refrescar.
- **Settings** (`/settings`) — ajustes generales (brillo/volumen, switches) y
  secciones Wi-Fi y Bluetooth: escaneo, conexión con contraseña, emparejar
  con PIN. Cualquier campo de texto saca el teclado en pantalla
  (`virtual_keypad`) automáticamente.

> El playback de audio en escritorio necesita GStreamer (ver prerequisitos del
> README). La reproducción real de streams puede tardar en enganchar según la
> emisora.

---

## 3) Comandos sueltos

| Quiero… | Comando |
|---------|---------|
| Verificar entorno | `scripts/validate.sh` |
| Rehacer la BD desde cero | `cd backend && npm run db:reset` |
| Explorar la BD | `cd backend && npm run db:studio` |
| Ver tablas SQL | `docker exec -it hiluxos_postgres psql -U hiluxos -d hiluxos -c '\dt'` |
| Parar Postgres | `docker compose -f docker/docker-compose.yml down` |
| Arrancar solo Postgres | `docker compose -f docker/docker-compose.yml up -d` |
| Migración de BD | `cd backend && npm run db:migrate` |
| Regenerar cliente Prisma | `cd backend && npm run db:generate` |

Logs del backend: salen en la terminal donde corre `scripts/dev.sh`.

---

## 4) Referencia API

Todo el backend sirve bajo `/api`. Esta es la superficie completa (fuente
única de la referencia; el README enlaza aquí).

### Health
```
GET /api/health                          ← liveness + BD
```

### System
```
GET    /api/system/info                  ← identidad del sistema
GET    /api/system/resources             ← CPU/RAM/temp/disco/uptime/load
GET    /api/system/internet              ← check de conectividad
GET|PUT /api/system/audio                ← volumen/mute del SO (body { volume?, muted? })
GET|PUT /api/system/brightness           ← brillo vía sysfs (body { brightness })
GET|PUT /api/system/network              ← WiFi on/off (body { enabled })
GET    /api/system/network/wifi/scan     ← escanear redes
POST   /api/system/network/wifi/connect  ← body { ssid, password }
POST   /api/system/network/wifi/disconnect
POST   /api/system/network/wifi/forget   ← body { ssid }
GET|PUT /api/system/bluetooth            ← BT on/off (body { powered })
GET    /api/system/network/bluetooth/scan
POST   /api/system/network/bluetooth/pair      ← body { mac, pin? }
POST   /api/system/network/bluetooth/connect   ← body { mac }
POST   /api/system/network/bluetooth/disconnect← body { mac }
POST   /api/system/network/bluetooth/remove    ← body { mac }
```

### Settings
```
GET|PUT|DELETE /api/settings/:key        ← upsert/borrar ajuste (body { value })
GET    /api/settings                     ← todos como { key: value }
```

### Radio
```
GET    /api/radio/stations/search?q=bbc  ← búsqueda en Radio Browser
GET    /api/radio/stream/:id             ← resolver URL real de la emisora
GET|POST /api/radio/favorites            ← favoritos (DELETE con ?url=)
GET|POST /api/radio/history              ← historial de reproducción
POST   /api/radio/spectrum/start         ← body { url, listenerId } (ffmpeg → WS)
POST   /api/radio/spectrum/stop          ← body { listenerId }
```

### Media
```
GET    /api/media/tracks?search=         ← biblioteca indexada
GET    /api/media/folders                ← carpetas configuradas (flag exists)
GET    /api/media/folders/browse?path=   ← un nivel de FS (picker de carpeta)
POST   /api/media/folders                ← body { path } (absoluta)
DELETE /api/media/folders/:id            ← quita carpeta y purga sus tracks
POST   /api/media/library/scan           ← re-escaneo incremental (ffprobe)
GET    /api/media/stream/:id             ← sirve el archivo (HTTP Range → seek)
POST   /api/media/tracks/:id/play        ← registra reproducción
GET    /api/media/tracks/:id/art         ← portada (404 si no hay)
DELETE /api/media/tracks/:id             ← quita del índice (el archivo queda)
```

### Tareas (Pendientes)
```
GET|POST /api/tasks · PUT|DELETE /api/tasks/:id
```

### Notificaciones
```
POST /api/notifications                  ← crear (toast + panel)
POST /api/notifications/check            ← forzar chequeo del monitor
GET  /api/notifications?limit=&cursor=   ← listar (paginado)
GET  /api/notifications/unread · /unread/count
PUT  /api/notifications/:id/read · PUT /read-all
DELETE /api/notifications/:id
```

### Registro de eventos
```
GET /api/event-log?limit=&cursor=&event=
```

### Updates (OTA)
```
GET  /api/updates                        ← estado + info de versión
POST /api/updates/check                  ← consulta VERSION.txt de master
POST /api/updates/apply                  ← body { version }: blue-green + restart
POST /api/updates/rollback               ← volver a la versión anterior
```

### Vehículo (HAL Fase 3 — driver por env `HAL_VEHICLE`)
```
GET  /api/vehicle                        ← snapshot: telemetría + luces + cierre
                                           + alarma + 4 ventanillas + 4 puertas
PUT  /api/vehicle/lights|signals|lock|ignition|alarm
PUT  /api/vehicle/doors/:id              ← body { open }
POST /api/vehicle/windows/:id/up|down|stop
```

### Power / GPIO (drivers por env `HAL_POWER` / `HAL_GPIO`)
```
GET /api/power                           ← salud energética (undervoltage/throttle)
GET /api/gpio · PUT /api/gpio/:id        ← pinout / escritura (body { value })
```

### WebSocket
```
WS /events                               ← eventos en tiempo real (sistema,
                                            notificaciones, espectro…)
```

### Ejemplos

```bash
curl http://localhost:3000/api/health
curl "http://localhost:3000/api/radio/stations/search?q=bbc"
curl -X PUT http://localhost:3000/api/settings/brightness \
  -H 'Content-Type: application/json' -d '{"value":"65"}'
```
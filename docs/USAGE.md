# Cómo usar hiluxOS

Guía práctica para correr el sistema en desarrollo (Fedora / Linux desktop).
El stack: **Flutter** (`app/`) + **NestJS** (`backend/`) + **PostgreSQL** (Docker).

---

## 1) Arranque limpio desde cero (lo que harías tras clonar)

En un terminal — **infra + backend**:

```bash
cd /home/xibhu/Development/GitHub/hiluxOS
scripts/setup.sh    # Postgres + dependencias + migración + seed (solo la 1ª vez)
scripts/dev.sh      # backend en http://localhost:3000 (modo watch)
```

En **otro terminal** — la app:

```bash
scripts/run-app.sh  # = flutter run -d linux
```

Se abre la ventana en el escritorio: Splash → Home (4 s) y barra inferior
(Home · Radio · System · Settings).

### Apuntar la app a la Raspberry Pi (producción)

```bash
flutter run -d linux \
  --dart-define=APP_API_URL=http://192.168.1.10:3000 \
  --dart-define=APP_WS_URL=ws://192.168.1.10:3000/events
```

---

## 2) Qué hacer en cada pantalla

- **Home** — dashboard con tarjetas (Radio, System, Temp, Settings) con datos
  en vivo del backend.
- **Radio**
  - Pestaña *Search*: escribe `bbc` (o `jazz`, `rock`) y dale al icono de
    enviar. Llega la lista real desde Radio Browser. Toca una → reproduce y se
    enciende el visualizador. El ♥ la guarda en favoritos (persiste en Postgres).
  - Pestaña *Favorites*: estaciones guardadas.
  - Pestaña *History*: lo reproducido.
- **System** — CPU, RAM, temperatura, uptime reales. Tira hacia abajo para
  refrescar.
- **Settings** — sliders de brillo/volumen y switches (wifi/bluetooth). Moverlos
  guarda el valor en la BD (recarga y sigue ahí).

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

## 4) API REST

Todo el backend sirve bajo `/api`.

```
GET  /api/health                  ← liveness + BD
GET  /api/system/info             ← identidad del sistema
GET  /api/system/resources        ← CPU/RAM/temp en vivo
GET  /api/settings                ← { key: value }
PUT  /api/settings/{key}          ← body {"value":"65"}
GET  /api/radio/stations/search?q=bbc
GET  /api/radio/favorites
POST /api/radio/favorites         ← body { name, url, ... }
GET  /api/radio/history
POST /api/radio/history           ← body { name, url, ... }
WS   /events                      ← eventos en tiempo real
```

Ejemplos:

```bash
curl http://localhost:3000/api/health
curl "http://localhost:3000/api/radio/stations/search?q=bbc"
curl -X PUT http://localhost:3000/api/settings/brightness \
  -H 'Content-Type: application/json' -d '{"value":"65"}'
```

---

## 5) Prerrequisitos (resumen)

- Node 22 LTS
- Flutter stable (`/home/xibhu/flutter/bin/flutter`)
- Docker Engine + Compose v2
- GStreamer dev (para `audioplayers` en Linux desktop):

```bash
sudo dnf install -y gstreamer1-devel gstreamer1-plugins-base-devel \
  gstreamer1-plugins-good gstreamer1-plugins-good-extras \
  gstreamer1-plugins-bad-free gstreamer1-plugins-bad-free-devel \
  gstreamer1-plugins-bad-free-extras gstreamer1-plugins-ugly-free
```

La configuración va por variables de entorno (nunca hardcodeada). Ver
[`../.env.example`](../.env.example). El backend lee `backend/.env`.
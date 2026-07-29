# hiluxOS — Guía de versiones, releases y mantenimiento

Este documento describe **todo** lo necesario para subir de versión, crear
releases, publicar bundles de UI para cada arquitectura, y mantener el flujo
de trabajo Git. Es la referencia para futuras sesiones de desarrollo.

> Última actualización: v0.1.0 · README vivo — mantener sincronizado con
> `VERSION.txt` y los scripts de `scripts/`.

---

## Tabla de contenidos

1. [Estructura del proyecto](#1-estructura-del-proyecto)
2. [Flujo de trabajo Git (ramas)](#2-flujo-de-trabajo-git-ramas)
3. [Cómo se versiona](#3-cómo-se-versiona)
4. [Arquitecturas objetivo](#4-arquitecturas-objetivo)
5. [Prerequisitos en la máquina de desarrollo](#5-prerequisitos-en-la-máquina-de-desarrollo)
6. [Publicar una nueva versión — paso a paso](#6-publicar-una-nueva-versión--paso-a-paso)
7. [Crear un bundle de UI para cada arquitectura](#7-crear-un-bundle-de-ui-para-cada-arquitectura)
8. [El instalador (install-pi.sh)](#8-el-instalador-install-pish)
9. [Sistema de actualizaciones OTA](#9-sistema-de-actualizaciones-ota)
10. [Layout en disco del dispositivo](#10-layout-en-disco-del-dispositivo)
11. [Servicios systemd](#11-servicios-systemd)
12. [Troubleshooting](#12-troubleshooting)
13. [Checklist rápido de release](#13-checklist-rápido-de-release)
---

## 1. Estructura del proyecto

```
hiluxOS/
├── VERSION.txt              ← número de versión actual (una línea, ej: 0.2.0)
├── app/                     ← Flutter UI (frontend)
│   └── lib/
│       ├── core/api/websocket_service.dart   ← WS plano (web_socket_channel)
│       └── core/utils/config.dart            ← APP_API_URL / APP_WS_URL (dart-define)
├── backend/                 ← NestJS + Prisma + PostgreSQL (backend)
│   ├── src/
│   │   ├── main.ts          ← bootstrap + attach del WebSocket server
│   │   └── modules/
│   │       ├── events/      ← EventsGateway (ws plano en /events)
│   │       ├── notifications/
│   │       └── updates/     ← OTA engine (check → download → apply → restart)
│   └── package.json         ← NO tiene @nestjs/websockets ni socket.io
├── scripts/
│   ├── install-pi.sh        ← instalador first-time (Debian minimal)
│   └── release-ui.sh        ← compila Flutter + sube bundle al GitHub Release
└── .github/                 ← (futuro: workflows CI)
```

**Puntos clave:**

- **`VERSION.txt`** es la única fuente de verdad del número de versión.
  El instalador, el sistema OTA y el script de release lo leen todos.
- El backend usa **WebSocket plano (`ws`)**, NO Socket.IO. La app Flutter usa
  `web_socket_channel`. Ambos deben mantenerse así — son incompatibles con
  Socket.IO/Engine.IO.
- El backend se compila en el dispositivo (npm ci → nest build → prune).
  La UI **no** se compila en el dispositivo: se publica precompilada como
---

## 2. Flujo de trabajo Git (ramas)

```
feature/develop  →  dev  →  master
   (trabajo)      (pruebas)  (releases + instalador)
```

### Convención

| Rama              | Uso                                              |
|-------------------|--------------------------------------------------|
| `feature/develop` | Desarrollo activo, commits directos             |
| `dev`             | Integración/pruebas. Merge fast-forward desde feature |
| `master`          | Estable. El instalador y el OTA leen de aquí    |

### Merge de un cambio a master

```bash
# 1. Asegúrate de estar en feature/develop con todo commiteado
git checkout feature/develop
git add -A && git commit -m "feat: ..."

# 2. Merge a dev (fast-forward)
git checkout dev
git merge feature/develop --ff-only

# 3. Merge a master (fast-forward)
git checkout master
git merge dev --ff-only

# 4. Push de las tres ramas
git push origin feature/develop
git push origin dev
git push origin master

# 5. Volver a feature para seguir trabajando
git checkout feature/develop
```

> ⚠ **Siempre fast-forward** (`--ff-only`). Esto mantiene el historial lineal
> y evita merges confusos. Si `--ff-only` falla, significa que las ramas
> divergieron — reorganiza antes de forzar un merge.

### Commit messages

Se usa Conventional Commits:

```
feat:     nueva funcionalidad
fix:      corrección de bug
docs:     documentación
chore:    tareas de mantenimiento
refactor: refactor sin cambio de comportamiento
```

---

## 3. Cómo se versiona

**SemVer**: `MAYOR.MENOR.PARCHE` (ej: `0.2.1`).

- **PARCHE** (`0.2.0 → 0.2.1`): bug fixes, sin nuevas APIs.
- **MENOR** (`0.2.0 → 0.3.0`): nuevas funcionalidades, retrocompatible.
- **MAYOR** (`0.3.0 → 1.0.0`): cambios rompedores.

El número vive en `VERSION.txt` (una sola línea, sin prefijo `v`):

```
$ cat VERSION.txt
0.1.0
```

Para subir de versión, edita `VERSION.txt` y commitea:

```bash
echo "0.2.0" > VERSION.txt
git add VERSION.txt
git commit -m "chore: bump version to 0.2.0"
```

**Importante:** la versión del `backend/package.json` (`"version": "0.1.0"`)
debe coincidir con `VERSION.txt`. El OTA usa `VERSION.txt` como fuente
principal, pero `package.json` es el fallback.
---

## 4. Arquitecturas objetivo

| Arquitectura       | `uname -m`  | Nombre del asset UI          | Dónde                      |
|--------------------|-------------|------------------------------|----------------------------|
| x86-64             | `x86_64`    | `hiluxos-ui-x86-64.tar.gz`   | VM VirtualBox (pruebas)    |
| ARM64 (aarch64)    | `aarch64`   | `hiluxos-ui-arm64.tar.gz`    | Raspberry Pi 4/5 (objetivo)|

El instalador detecta la arquitectura con `uname -m` y descarga el asset
correcto:

```bash
hiluxos-ui-${UI_ARCH}.tar.gz
# donde UI_ARCH = x86-64 | arm64
```

> ⚠ **El bundle de UI es específico de arquitectura.** Un bundle x86-64 no
> funciona en ARM64 y viceversa. Cada release debe tener el asset de cada
> arquitectura que se soporte.

---

## 5. Prerequisitos en la máquina de desarrollo

Para publicar versiones necesitas:

1. **Flutter SDK** en PATH (para compilar la UI)
   ```bash
   flutter --version   # debe responder
   ```

2. **gh CLI** autenticado (para crear releases y subir assets)
   ```bash
   # Instalar (Fedora):
   sudo dnf install gh
   # O descargar de: https://github.com/cli/cli/releases

   # Autenticar (una sola vez):
   gh auth login
   # → GitHub.com → HTTPS → Login with a web browser
   # → Pegar el código, autorizar

   # Verificar:
   gh auth status
   ```

3. **Node.js 22 LTS** (para desarrollo del backend)
4. **Git** con acceso push a `github.com:xibhuxan/hiluxOS.git`

> El script `release-ui.sh` verifica `gh auth status` y `flutter` antes de
> hacer nada. Si falta algo, aborta con un mensaje claro.
---

## 6. Publicar una nueva versión — paso a paso

Este es el flujo **completo** para sacar una nueva versión. Hazlo desde la
rama `feature/develop`.

### Paso 1 — Subir el número de versión

```bash
# En feature/develop
echo "0.2.0" > VERSION.txt
# Asegúrate de que backend/package.json también dice 0.2.0
# (campo "version")
git add VERSION.txt backend/package.json
git commit -m "chore: bump version to 0.2.0"
```

### Paso 2 — Compilar y subir el bundle de UI

Para cada arquitectura que soportes:

```bash
# En la máquina x86-64 (tu PC / VM de build):
scripts/release-ui.sh
# → compila x64, crea/sube hiluxos-ui-x86-64.tar.gz al release v0.2.0

# Para ARM64 (Raspberry Pi):
# Opción A — cross-compile (si tienes el toolchain arm64 configurado):
scripts/release-ui.sh --arm64

# Opción B — compilar nativamente en una Pi/arm64:
#   1. Instala Flutter en la Pi (o en una VM arm64)
#   2. Clona el repo, checkout a la versión que vas a publicar
#   3. scripts/release-ui.sh
#   → detecta aarch64 automáticamente y nombra el asset hiluxos-ui-arm64.tar.gz
```

El script hace automáticamente:
- Lee `VERSION.txt` → `0.2.0`
- `flutter build linux --release` con las URLs correctas via `--dart-define`
- Empaqueta el bundle en `hiluxos-ui-<arch>.tar.gz`
- Si el release `v0.2.0` no existe → lo crea (`gh release create`)
- Si ya existe → sube el asset sobreescribiendo (`--clobber`)

> Puedes subir bundles de arquitecturas diferentes en momentos distintos al
> mismo release. El `--clobber` solo afecta al asset concreto, no al release.

### Paso 3 — Merge a master y push

```bash
git checkout dev
git merge feature/develop --ff-only
git checkout master
git merge dev --ff-only
git push origin feature/develop dev master
git checkout feature/develop
```

### Paso 4 — Verificar

```bash
# El release existe y tiene los assets:
gh release view v0.2.0

# Los assets son descargables públicamente:
curl -fsSL -o /dev/null -w "%{http_code}" \
  https://github.com/xibhuxan/hiluxOS/releases/download/v0.2.0/hiluxos-ui-x86-64.tar.gz
# → 200
```

### Paso 5 — Verificar en un dispositivo

En una VM/Pi limpia:

```bash
curl -fsSL https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/scripts/install-pi.sh | sudo bash
```

Debe terminar con:
```
═══════════════════════════════════════════════════════════════
  hiluxOS 0.2.0 installed successfully!
═══════════════════════════════════════════════════════════════

  Backend:    http://<ip>:3000
  Services:   systemctl status hiluxos-backend hiluxos-ui
  UI:         Cage Wayland kiosk running on the physical display
```

Y la interfaz debe verse en la pantalla.
---

## 7. Crear un bundle de UI para cada arquitectura

El bundle de UI es un `.tar.gz` que contiene el directorio `bundle/` que
genera `flutter build linux --release`:

```
bundle/
├── hiluxos                    ← binario compilado (elf, arch-específico)
├── lib/                       ← lib/*.so de Flutter
├── data/                      ← assets, fonts, kernel_blob
└── ...
```

### x86-64 (VM VirtualBox, tu PC)

```bash
scripts/release-ui.sh
```

Compila en `build/linux/x64/release/bundle/`, empaqueta como
`hiluxos-ui-x86-64.tar.gz`, sube al release.

### ARM64 (Raspberry Pi 4/5)

**Opción recomendada — compilar nativamente en una Pi arm64:**

La Pi 4/5 con 4GB+ puede compilar Flutter. Es lo más fiable porque el
binario y las libs son exactamente para el target.

1. Instala Flutter en la Pi:
   ```bash
   # Raspberry Pi OS Lite 64-bit (Bookworm)
   sudo apt install -y clang cmake ninja-build pkg-config \
     libgtk-3-dev libstdc++-12-dev
   # Descarga Flutter SDK:
   git clone https://github.com/flutter/flutter.git ~/flutter
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc
   source ~/.bashrc
   flutter doctor
   flutter config --enable-linux-desktop
   ```

2. Clona el repo en la versión que vas a publicar:
   ```bash
   git clone https://github.com/xibhuxan/hiluxOS.git
   cd hiluxOS
   git checkout v0.2.0   # o el tag/commit que sea
   ```

3. Ejecuta el script:
   ```bash
   scripts/release-ui.sh
   # → detecta aarch64, nombra el asset hiluxos-ui-arm64.tar.gz
   ```

**Opción alternativa — cross-compile desde x86-64:**

```bash
scripts/release-ui.sh --arm64
```

Esto requiere tener configurado el toolchain de cross-compilación arm64
para Flutter Linux. Es más frágil; si da errores de linker, usa la opción
nativa.

### Verificar que un bundle tiene todas sus dependencias

El instalador hace esto automáticamente con `ldd`:

```bash
ldd /opt/hiluxos/ui/hiluxos | grep "not found"
# → no debe mostrar nada. Si muestra líneas, falta una lib en el target.
```

Si una lib falta, añádela al `apt-get install` del `install-pi.sh`.
---

## 8. El instalador (install-pi.sh)

**Ubicación:** `scripts/install-pi.sh`
**Uso:**

```bash
# Método 1 — una sola línea (sin clonar el repo):
curl -fsSL https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/scripts/install-pi.sh | sudo bash

# Método 2 — tras clonar:
sudo bash scripts/install-pi.sh
```

**Qué hace (en orden):**

1. **apt update + install** — paquetes base + cage + librerías runtime Flutter
   + PostgreSQL + Node.js 22
2. **PostgreSQL** — crea usuario `hiluxos` y base de datos `hiluxos`
3. **Usuario sistema** — crea el usuario `hiluxos`
4. **Download repo** — baja el tarball de master, extrae a
   `/opt/hiluxos/versions/<VERSION>/`
5. **Backend** — `npm ci`, `nest build`, `npm prune --omit=dev`
6. **.env** — crea `/opt/hiluxos/current/backend/.env` con la URL de la BD
7. **Migraciones** — `prisma migrate deploy`
8. **Symlink** — `current → versions/<VERSION>`
9. **Servicio backend** — crea `hiluxos-backend.service`, enable + start
10. **Verifica** — espera a que `/api/health` responda
11. **UI** — descarga `hiluxos-ui-<arch>.tar.gz` del release, extrae a
    `/opt/hiluxos/ui/`, verifica con `ldd`
12. **Servicio UI** — crea `hiluxos-ui.service` (cage kiosk), enable + start
13. **Limpieza** — `apt-get clean`

**Log de instalación:** todo se guarda en `/var/log/hiluxos-install.log`
(con un banner con timestamp al inicio de cada ejecución).

**Si el bundle de UI no existe para esa arquitectura:** el instalador avisa
pero continúa — el backend queda funcionando, solo sin UI. Para arreglarlo,
publica el bundle y re-ejecuta el install, o descarga el bundle manualmente.
---

## 9. Sistema de actualizaciones OTA

El backend tiene un motor de OTA en `backend/src/modules/updates/`.

### Cómo funciona

```
[App: Settings → Updates]
        │
        │  POST /api/updates/check
        ▼
  fetch VERSION.txt de master  ──→  comparar con versión local
        │
        │  POST /api/updates/apply { version: "0.2.0" }
        ▼
  1. download master.tar.gz → /opt/hiluxos/releases/
  2. extract → /opt/hiluxos/versions/0.2.0/
  3. npm ci (full, con devDeps)
  4. nest build
  5. prisma migrate deploy
  6. npm prune --omit=dev
  7. swap symlink: current → versions/0.2.0  (atómico)
  8. notificación: "Sistema actualizado"
  9. process.exit(0) → systemd reinicia el backend
```

### Endpoints de la API

| Método | Ruta                     | Descripción                     |
|--------|--------------------------|---------------------------------|
| GET    | `/api/updates`           | Estado actual + info de versión |
| POST   | `/api/updates/check`     | Comprueba si hay versión nueva  |
| POST   | `/api/updates/apply`     | Aplica la actualización         |
| POST   | `/api/updates/rollback`  | Vuelve a la versión anterior    |

### Blue-green con rollback

- Cada versión se instala en `/opt/hiluxos/versions/<X.Y.Z>/` (no se borra).
- `current` es un symlink a la versión activa.
- Si algo va mal, `POST /api/updates/rollback` repunta el symlink a la
  versión anterior y reinicia.
- El estado de cada intento se guarda en la tabla `UpdateLog` de PostgreSQL.

### ⚠ Limitación actual del OTA

El OTA **solo actualiza el backend** (descarga master.tar.gz que contiene
todo el repo, pero solo reconstruye el backend). **La UI no se actualiza
vía OTA todavía** — el bundle de UI solo se instala en el primer `install-pi.sh`.

Para actualizar la UI hoy:
- Re-ejecutar `install-pi.sh` (descarga el bundle nuevo del release), o
- Descargar manualmente el bundle y reemplazar `/opt/hiluxos/ui/`.

**TODO futuro:** extender el OTA para que también descargue el bundle de UI
del GitHub Release y reinicie `hiluxos-ui.service`.
---

## 10. Layout en disco del dispositivo

```
/opt/hiluxos/
├── current → versions/0.2.0        ← symlink a la versión activa (backend)
├── versions/
│   ├── 0.1.0/                      ← versión anterior (backup para rollback)
│   │   ├── backend/
│   │   │   ├── dist/main.js        ← código compilado
│   │   │   ├── node_modules/       ← solo prod deps
│   │   │   ├── prisma/
│   │   │   └── .env
│   │   └── VERSION.txt
│   └── 0.2.0/                      ← versión actual
│       └── (igual)
├── ui/                             ← UI (no versionada, bundle del release)
│   ├── hiluxos                     ← binario Flutter
│   ├── lib/
│   └── data/
└── releases/                       ← tarballs descargados (cache)

/var/log/hiluxos-install.log        ← log del primer install
```

---

## 11. Servicios systemd

### `hiluxos-backend.service`

```ini
[Unit]
Description=hiluxOS backend API
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=hiluxos
WorkingDirectory=/opt/hiluxos/current/backend
EnvironmentFile=/opt/hiluxos/current/backend/.env
ExecStart=/usr/bin/node dist/main.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### `hiluxos-ui.service`

```ini
[Unit]
Description=hiluxOS UI (Cage Wayland kiosk + Flutter app)
After=hiluxos-backend.service
Wants=hiluxos-backend.service

[Service]
Type=simple
User=root
Environment=XDG_RUNTIME_DIR=/run/user/0
Environment=HOME=/root
Environment=LIBSEAT_BACKEND=seatd      # sin sesión logind → backend seatd
Environment=WLR_RENDERER=pixman        # software rendering (fallback seguro)
Environment=XCURSOR_THEME=Adwaita      # tema de cursor (pointer visible)
Environment=XCURSOR_SIZE=24
ExecStart=/usr/bin/cage -- /opt/hiluxos/ui/hiluxos
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

**Comandos útiles:**

```bash
systemctl status hiluxos-backend hiluxos-ui
journalctl -u hiluxos-backend -f      # log del backend
journalctl -u hiluxos-ui -f           # log del cage + Flutter
systemctl restart hiluxos-backend     # reinicia solo el backend
systemctl restart hiluxos-ui          # reinicia solo la UI
```

> `WLR_RENDERER=pixman` fuerza software rendering. Es seguro en todos lados
> (VirtualBox sin 3D, Pi con VC4/V3D). wlroots lo usa solo si EGL falla.
> En la Pi real, puedes probar a quitarlo para usar la GPU (más fluidez).
---

## 12. Troubleshooting

### La UI no arranca (cage falla)

```bash
journalctl -u hiluxos-ui -e
```

Errores comunes:
- `Could not get primary session for user` — falta el backend seatd. El
  instalador instala y arranca `seatd` y pone `LIBSEAT_BACKEND=seatd` en el
  servicio. Si aparece, verifica `systemctl is-active seatd` y que el
  servicio tiene `Environment=LIBSEAT_BACKEND=seatd`.
- `Failed to parse EDID` — normal en VirtualBox, ignóralo.
- `cannot open display` — cage no encuentra /dev/dri. Verifica que el
  dispositivo de display está conectado (HDMI/DSI).
- `Unable to load from the cursor theme` — falta `adwaita-icon-theme` o
  `XCURSOR_THEME` no está puesto. El puntero funciona aunque no se vea.

### El binario de UI falta libs

```bash
ldd /opt/hiluxos/ui/hiluxos | grep "not found"
```

Cada lib que falte hay que añadirla al `apt-get install` del instalador.

### WebSocket: "Connection closed before full header"

Esto pasa si el backend usa Socket.IO pero la app usa WS plano. **Solución:**
el backend debe usar `ws` (no `@nestjs/websockets`/`socket.io`). Verifica
`backend/package.json` — no debe tener `socket.io` ni
`@nestjs/platform-socket.io`.

### El OTA no detecta la nueva versión

1. Verifica que `VERSION.txt` en master tiene el número nuevo:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/VERSION.txt
   ```
2. El número debe ser **mayor** (semver) que la versión local.
3. El backend hace la comparación con `compareVersions()` — solo aplica si
   la remota es mayor.

### El install no encuentra el bundle de UI

```bash
# Verifica que el asset existe y es público:
curl -fsSL -o /dev/null -w "%{http_code}" \
  https://github.com/xibhuxan/hiluxOS/releases/download/v<VERSION>/hiluxos-ui-<arch>.tar.gz
# → 200 = OK, 404 = no existe (publícalo con release-ui.sh)
```

### gh CLI: "could not find upload URL"

El release no existe todavía. `release-ui.sh` lo crea automáticamente, pero
si lo haces a mano:

```bash
gh release create v0.2.0 --title "hiluxOS v0.2.0" --notes "..."
gh release upload v0.2.0 hiluxos-ui-x86-64.tar.gz --clobber
```
---

## 13. Checklist rápido de release

Copia esto cada vez que vayas a publicar una versión:

```bash
# ▢ 1. Estar en feature/develop con todo commiteado
git checkout feature/develop
git status   # clean

# ▢ 2. Subir versión
echo "0.2.0" > VERSION.txt
# editar backend/package.json → "version": "0.2.0"
git add VERSION.txt backend/package.json
git commit -m "chore: bump version to 0.2.0"

# ▢ 3. Compilar + subir bundle UI (x86-64)
scripts/release-ui.sh
# ✓ ver: "Asset uploaded: .../hiluxos-ui-x86-64.tar.gz"

# ▢ 4. Compilar + subir bundle UI (arm64) — en una Pi o cross-compile
# scripts/release-ui.sh --arm64   (o nativo en Pi)
# ✓ ver: "Asset uploaded: .../hiluxos-ui-arm64.tar.gz"

# ▢ 5. Merge a master
git checkout dev && git merge feature/develop --ff-only
git checkout master && git merge dev --ff-only
git push origin feature/develop dev master
git checkout feature/develop

# ▢ 6. Verificar el release
gh release view v0.2.0
# ✓ ver ambos assets listados

# ▢ 7. Verificar assets descargables
curl -fsSL -o /dev/null -w "%{http_code}" \
  https://github.com/xibhuxan/hiluxOS/releases/download/v0.2.0/hiluxos-ui-x86-64.tar.gz
# → 200

# ▢ 8. Probar install limpio en VM
curl -fsSL https://raw.githubusercontent.com/xibhuxan/hiluxOS/master/scripts/install-pi.sh | sudo bash
# ✓ ver interfaz en pantalla
# ✓ curl http://localhost:3000/api/health → {"status":"ok",...}
```

---

## Notas para futuros chats

- **No reiniciar el backend** si está en `npm run start:dev --watch` — el
  watcher lo reinicia solo al detectar cambios.
- **Siempre fast-forward** en los merges de rama.
- **VERSION.txt** es la única fuente de verdad de versión — sincronizar con
  `backend/package.json`.
- **WebSocket = `ws` plano**, nunca Socket.IO en el backend.
- **El bundle de UI va en el GitHub Release**, no en el repo. El repo solo
  tiene el código fuente; el binario compilado es un asset del release.
- **El instalador lee de master** — nada está publicado hasta que está en
  master y pusheado.
- **VM de pruebas**: Debian minimal en VirtualBox, SSH en puerto 2222
  (`ssh -p 2222 prueba@localhost`), contraseña `granyugio`. Clave SSH
  autorizada para acceso sin password.
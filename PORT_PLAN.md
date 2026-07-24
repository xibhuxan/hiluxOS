# Plan de Port: hiluxOS → Node.js (NestJS) + Flutter

## Visión General

**De:** Python monolítico (PySide6 + QML) con descubrimiento vertical de apps  
**A:** Backend Node.js independiente (NestJS) + Frontend Flutter independiente, comunicándose por REST/WebSocket. Python como microservicio opcional futuro.

```
┌─────────────────────┐     REST / WebSocket      ┌──────────────────────────┐
│   FLUTTER (Dart)    │ ◄──────────────────────► │  NODE.JS (NestJS)        │
│   - UI/UX           │                           │  - API + Servicios       │
│   - Navegación      │                           │  - HAL (system calls)    │
│   - Audio playback  │     WebSocket             │  - PostgreSQL            │
│   - Visualizador    │ ◄──────────────────────► │                          │
│                     │                           │  ┌────────────────────┐  │
│                     │        Invidious API      │  │ Python Microserv.  │  │
│                     │ ◄──────────────────────►  │  │ (voz/IA - futuro)  │  │
│                     │                           │  └────────────────────┘  │
└─────────────────────┘                           └──────┬───────────────────┘
                                                       │
                                              ┌────────┴────────┐
                                              │  PostgreSQL     │
                                              │  (datos, favs,  │
                                              │   history, etc) │
                                              └─────────────────┘

Nota: Invidious se monta en Docker en el mismo host que NestJS.
     Flutter NO se conecta a Invidious directamente; Node actúa de proxy.
```

---

## Mapeo de Componentes: Python → Node.js + Flutter

### 1. Core → Backend (NestJS)

| Python | Node.js (NestJS) | Notas |
|--------|------------------|-------|
| `EventBus` | WebSocket Gateway + EventEmitter | Los eventos se vuelven mensajes WebSocket (`ws://host/events`) |
| `AppManager` | `PluginModule` + `DiscoveryService` | NestJS modules auto-registradas vía decoradores, no discovery de filesystem |
| `QmlBridge` | **Eliminado** | Flutter llama a la API directamente, sin bridge necesario |

### 2. HAL → Backend Services (Node.js)

| Python HAL | Node.js Service | Implementación |
|------------|-----------------|----------------|
| `GPIOController` | `GpioService` | `node-gpio` / `/sys/class/gpio` / `onoff` package. Mock en dev. |
| `PowerManager` | `PowerService` | `systemd` via `child_process.exec()`, `/proc/acpi/...` |
| `VehicleSignals` | `VehicleSignalsService` | OBD-II via serial (`serialport`), mock con generador de señales |

### 3. Apps/Servicios → NestJS Modules

| App Python | Módulo NestJS | API Endpoints |
|------------|---------------|---------------|
| `RadioService` (VLC + Radio Browser) | `RadioModule` | `GET /radio/stations/search?q=`, `GET /radio/stream/{id}` → URL de stream, `GET /radio/favorites`, `POST /radio/favorites`, `DELETE /radio/favorites/:url`, `GET /radio/history`, `GET /radio/status` |
| `MediaPlayerService` | `MediaModule` | `POST /media/play`, `POST /media/pause`, `POST /media/stop`, `GET /media/playlist`, `POST /media/playlist/add` |
| `SystemInfoService` | `SystemModule` | `GET /system/info`, `GET /system/resources` (CPU/RAM/uptime via `os` + `/proc`) |
| `SettingsService` | `SettingsModule` | `GET /settings`, `PUT /settings/:key`, `DELETE /settings/:key` |

### 4. UI QML → Flutter Widgets

| QML Component | Widget Flutter Equivalente |
|---------------|---------------------------|
| `Main.qml` (Window + StackView) | `MaterialApp` + `go_router` con `ShellRoute` |
| `SplashScreen.qml` | `AnimatedContainer` + `CircularProgressIndicator` + video (`video_player`) |
| `Home.qml` (dashboard grid) | `GridView.count` con `DashboardCard` widgets |
| `BottomBar.qml` | `NavigationBar` (Material 3) o `BottomAppBar` custom |
| `DashboardCard.qml` | `Card` widget con `InkWell` y animaciones |
| `Radio.qml` | Screen con `TabBarView`, búsqueda, lista de estaciones |
| `MediaPlayer.qml` | Screen con reproductor, controles, playlist |
| `SystemInfo.qml` | Screen con `ListView` de cards informativas |
| `Settings.qml` | Screen con `ListTile` switches/sliders |

---

## Arquitectura Detallada: Backend (NestJS)

### Estructura del Proyecto

```
backend/
├── src/
│   ├── main.ts                    # Entry point
│   ├── app.module.ts              # Root module
│   │
│   ├── common/
│   │   ├── decorators/            # Custom decorators
│   │   ├── filters/               # Exception filters
│   │   ├── guards/                # Auth guards (futuro)
│   │   └── interceptors/          # Response interceptors
│   │
│   ├── modules/
│   │   ├── radio/
│   │   │   ├── radio.module.ts
│   │   │   ├── radio.controller.ts
│   │   │   ├── radio.service.ts
│   │   │   └── dto/
│   │   │       ├── search-station.dto.ts
│   │   │       └── play-station.dto.ts
│   │   │
│   │   ├── media/
│   │   │   ├── media.module.ts
│   │   │   ├── media.controller.ts
│   │   │   └── media.service.ts
│   │   │
│   │   ├── system/
│   │   │   ├── system.module.ts
│   │   │   ├── system.controller.ts
│   │   │   └── system.service.ts
│   │   │
│   │   ├── settings/
│   │   │   ├── settings.module.ts
│   │   │   ├── settings.controller.ts
│   │   │   ├── settings.service.ts
│   │   │   └── entities/
│   │   │       ├── setting.entity.ts
│   │       ├── favorite.entity.ts     # Estaciones favoritas
│   │       └── history.entity.ts      # Historial de reproducción
│   │   │
│   │   ├── vehicle/               # Reemplaza VehicleSignals HAL
│   │   │   ├── vehicle.module.ts
│   │   │   ├── vehicle.controller.ts
│   │   │   └── vehicle.service.ts
│   │   │
│   │   ├── gpio/                  # Reemplaza GPIOController HAL
│   │   │   ├── gpio.module.ts
│   │   │   ├── gpio.controller.ts
│   │   │   └── gpio.service.ts
│   │   │
│   │   ├── power/                 # Reemplaza PowerManager HAL
│   │   │   ├── power.module.ts
│   │   │   ├── power.controller.ts
│   │   │   └── power.service.ts
│   │   │
│   │   └── events/                # Reemplaza EventBus + WebSocket Gateway
│   │       ├── events.gateway.ts
│   │       └── events.module.ts
│   │
│   └── config/
│       ├── database.config.ts     # TypeORM/Prisma + PostgreSQL
│       └── app.config.ts
│
├── prisma/                        # Esquema de BD (PostgreSQL)
│   └── schema.prisma
├── package.json
├── tsconfig.json
├── nest-cli.json
└── .env
```

### Comunicación Backend ↔ Flutter

**REST (peticiones puntuales):**
- `GET /radio/stations/search?q=bbc` → lista de estaciones con URLs de stream
- `GET /radio/stream/{id}` → URL directa del stream para Flutter
- `GET /system/info` → info del sistema
- `GET /settings` → todas las configuraciones
- `PUT /settings/brightness` `{ "value": 80 }` → cambiar ajuste

Nota: No existe `POST /radio/play`. Flutter recibe la URL del stream y reproduce directamente con `just_audio`. El backend solo gestiona datos.

**WebSocket (estado en tiempo real):**
- Canal: `ws://host:3000/events`
- Eventos que el backend publica:
  - `vehicle:speed` — velocidad del vehículo
  - `vehicle:reverse` — marcha atrás
  - `vehicle:brake` — freno
  - `vehicle:ignition` — encendido/apagado
  - `radio:now_playing` — estación actual cambiando
  - `radio:status` — playing/paused/stopped + volumen
  - `gpio:pin_changed` — cambio de estado GPIO
  - `system:boot_complete` — sistema listo

**Flutter escucha así:**
```dart
// En un provider o service
class EventBusService {
  final WebSocket _ws = WebSocket('ws://backend:3000/events');
  
  void listen(String event, Function(dynamic) callback) {
    _ws.listen((data) {
      final msg = jsonDecode(data);
      if (msg['event'] == event) callback(msg['data']);
    });
  }
}
```

---

## Arquitectura Detallada: Frontend (Flutter)

### Estructura del Proyecto

```
frontend/
├── lib/
│   ├── main.dart                  # Entry point
│   │
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart    # HTTP client (dio/http)
│   │   │   ├── websocket_service.dart  # WS connection + reconnection
│   │   │   └── endpoints.dart     # Constantes de rutas API
│   │   │
│   │   ├── theme/
│   │   │   ├── app_theme.dart     # Dark/light themes (mismo palette que QML)
│   │   │   ├── colors.dart        # Colores: #0d1117, #58a6ff, etc.
│   │   │   └── typography.dart
│   │   │
│   │   └── utils/
│   │       └── constants.dart     # Device dimensions, timeouts, etc.
│   │
│   ├── features/
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── dashboard_card.dart    # ← DashboardCard.qml
│   │   │   │   └── status_card.dart
│   │   │   └── providers/
│   │   │       └── home_provider.dart     # Riverpod
│   │   │
│   │   ├── radio/
│   │   │   ├── radio_screen.dart          # ← Radio.qml (con visualizador)
│   │   │   ├── widgets/
│   │   │   │   ├── station_list_tile.dart
│   │   │   │   ├── playback_controls.dart
│   │   │   │   ├── search_bar.dart
│   │   │   │   └── spectrum_visualizer.dart    # Barritas FFT al ritmo del audio
│   │   │   └── providers/
│   │   │       ├── radio_provider.dart        # Estado de búsqueda, favorites
│   │   │       └── audio_player_provider.dart # just_audio + processedAudioSampleStream
│   │   │
│   │   ├── media/
│   │   │   ├── media_screen.dart          # ← MediaPlayer.qml
│   │   │   ├── widgets/
│   │   │   └── providers/
│   │   │       └── media_provider.dart
│   │   │
│   │   ├── system_info/
│   │   │   ├── system_info_screen.dart    # ← SystemInfo.qml
│   │   │   ├── widgets/
│   │   │   │   └── resource_card.dart
│   │   │   └── providers/
│   │   │       └── system_provider.dart
│   │   │
│   │   ├── settings/
│   │   │   ├── settings_screen.dart       # ← Settings.qml
│   │   │   ├── widgets/
│   │   │   │   ├── setting_tile.dart
│   │   │   │   └── brightness_slider.dart
│   │   │   └── providers/
│   │   │       └── settings_provider.dart
│   │   │
│   │   └── splash/
│   │       ├── splash_screen.dart         # ← SplashScreen.qml (animado)
│   │       └── providers/
│   │           └── splash_provider.dart
│   │
│   ├── layout/
│   │   ├── app_shell.dart                 # Layout principal (body + bottom nav)
│   │   ├── bottom_navigation.dart         # ← BottomBar.qml
│   │   └── navigation_router.dart         # go_router config
│   │
│   └── widgets/                           # Widgets globales reutilizables
│       ├── animated_value_text.dart
│       └── loading_overlay.dart
│
├── pubspec.yaml
├── analysis_options.yaml
└── assets/
    ├── images/                            # hilux_99.png, etc.
    └── video/                             # splash.mp4
```

### Navegación (go_router)

```dart
// Equivalente al StackView.push/pop de QML
final router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => SplashScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => HomeScreen()),
        GoRoute(path: 'radio', builder: (_, __) => RadioScreen()),
        GoRoute(path: 'media', builder: (_, __) => MediaScreen()),
        GoRoute(path: 'system', builder: (_, __) => SystemInfoScreen()),
        GoRoute(path: 'settings', builder: (_, __) => SettingsScreen()),
      ],
    ),
  ],
);
```

### Estado (Riverpod)

```dart
// Equivalente a las propiedades QML + bridge signals
@riverpod
class RadioState extends _$RadioState {
  @override
  RadioModel build() => RadioModel.initial();

  Future<void> searchStations(String query) async {
    final result = await ref.read(apiClientProvider).get('/radio/stations/search?q=$query');
    state = state.copyWith(searchResults: result);
  }

  // Flutter reproduce directamente — no hay endpoint /radio/play
  Future<void> playStation(Station station) async {
    final audioPlayer = ref.read(audioPlayerProvider);
    await audioPlayer.setUrl(station.streamUrl);  // just_audio abre el stream
    state = state.copyWith(isPlaying: true, currentStation: station);
  }

  void pause() {
    ref.read(audioPlayerProvider).pause();
    state = state.copyWith(isPlaying: false);
  }
}

// WebSocket listener que actualiza providers
@Riverpod]
Future<void> listenVehicleSignals(ListenVehicleSignalsRef ref) async {
  ref.watch(eventBusProvider).on('vehicle:speed', (data) {
    ref.read(vehicleSpeedProvider.notifier).update(data['speed']);
  });
}

// Visualizador — consume samples del audio player y calcula FFT
class SpectrumVisualizer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final player = context.watch(audioPlayerProvider);
    return StreamBuilder<Uint8List>(
      stream: player.processedAudioSampleStream,
      builder: (ctx, snapshot) {
        final samples = snapshot.data ?? Uint8List(0);
        final fft = computeFFT(samples);  // Fast Fourier Transform
        return CustomPaint(painter: SpectrumPainter(fft: fft));
      },
    );
  }
}
```

---

## Mapeo de Datos: Manifest → API

El sistema de discovery por filesystem (`apps/*/manifest.json`) se reemplaza con **módulos NestJS declarativos**. No hay discovery dinámico — los módulos se registran en `app.module.ts`.

Si se quiere discovery dinámico (como el original), se puede añadir un endpoint:
```
GET /plugins/discover    → lista de plugins cargados
POST /plugins/install    → instalar plugin remoto
DELETE /plugins/:name    → desinstalar
```

---

## Migración Paso a Paso

### Fase 0: Preparación (día 1)
- [ ] Crear repositorio `hiluxOS-backend` con NestJS scaffold
- [ ] Crear repositorio `hiluxOS-frontend` con Flutter scaffold
- [ ] Configurar Docker Compose para desarrollo local (backend + SQLite)
- [ ] Definir OpenAPI spec compartida (contract-first)

### Fase 1: Backend Core (días 2-4)
- [ ] `EventsGateway` — WebSocket pub/sub reemplazando EventBus
- [ ] `SystemModule` — info del sistema (`os`, `/proc`, uptime)
- [ ] `SettingsModule` — CRUD con PostgreSQL (Prisma ORM)
- [ ] Esquema Prisma: `Setting`, `Favorite`, `History`
- [ ] Health check endpoint `GET /health`

### Fase 2: HAL Services (días 5-7)
- [ ] `GpioService` — mock primero, luego `/sys/class/gpio` real
- [ ] `PowerService` — systemd hooks, shutdown/reboot
- [ ] `VehicleSignalsService` — generador de señales mock + OBD-II serial

### Fase 3: App Services (días 8-12)
- [ ] `RadioModule` — Radio Browser API, devuelve URLs de stream limpias a Flutter
- [ ] `MediaModule` — playlist local, metadatos de archivos
- [ ] Backend solo gestiona datos/estado; **Flutter reproduce audio** con `just_audio` + visualizador FFT

### Fase 4: Frontend — Layout Base (días 13-15)
- [ ] `main.dart` + tema oscuro (colores idénticos al QML: `#0d1117`, `#58a6ff`, etc.)
- [ ] `AppShell` con bottom navigation bar
- [ ] `go_router` configurado
- [ ] API client + WebSocket service con reconexión automática

### Fase 5: Frontend — Pantallas (días 16-22)
- [ ] `SplashScreen` — animación de entrada + logo glow + progress bar
- [ ] `HomeScreen` — dashboard grid con DashboardCards
- [ ] `RadioScreen` — búsqueda, playback controls, spectrum visualizer (FFT), tabs (search/favorites/history)
- [ ] `MediaScreen` — player básico
- [ ] `SystemInfoScreen` — cards de recursos del sistema
- [ ] `SettingsScreen` — sliders, switches, info

### Fase 6: Integración y Pulido (días 23-28)
- [ ] WebSocket en vivo: velocidad, reverse, brake → Flutter actualiza UI
- [ ] Animaciones de transición entre pantallas (equivalente a pushEnter/popExit)
- [ ] Manejo de offline / sin conexión al backend
- [ ] Testing: unitarios (Riverpod providers), widget tests, integration tests

### Fase 7: Python Microservicio (futuro, opcional)
- [ ] `voice-service/` — Flask/FastAPI independiente
- [ ] Wake word detection (`porcupine` o similar)
- [ ] STT (`vosk` o `whisper`)
- [ ] TTS (`pyttsx3` o `gTTS`)
- [ ] Comunicación con NestJS via gRPC o REST

---

## Decisiones Clave

### 1. ¿PostgreSQL?
**PostgreSQL** (vía Prisma ORM), montado en Docker. Con Docker funciona bien en la Pi y escala mejor que SQLite para este proyecto (múltiples servicios, concurrencia, futuras migraciones).

```yaml
# docker-compose.yml
postgres:
  image: postgres:16-alpine
  volumes: ["pgdata:/var/lib/postgresql/data"]
  environment:
    POSTGRES_USER: hiluxos
    POSTGRES_PASSWORD: <secret>
    POSTGRES_DB: hiluxos
```

```env
# .env del backend
DATABASE_URL="postgresql://hiluxos:<password>@postgres:5432/hiluxos"
```

### 3. ¿NestJS o Express directo?
**NestJS**. El índice lo especifica, y da estructura (modules, decorators, DI) que escala bien. Para un proyecto pequeño al inicio puede parecer boilerplate, pero los módulos del índice (Bluetooth, OBD, Voice, Camera, etc.) justificarán la arquitectura.

### 4. ¿Cómo manejar el HAL sin Raspberry Pi en dev?
**Mock-first con switch de configuración**:
```typescript
// gpio.service.ts
@Injectable()
export class GpioService {
  private readonly isReal = process.env.GPIO_REAL === 'true';
  
  async digitalWrite(pin: number, value: boolean) {
    if (!this.isReal) return true; // Mock
    // Real implementation via /sys/class/gpio
  }
}
```

### 4. Audio: ¿quién reproduce?
**Flutter reproduce todo.** Node.js gestiona datos (URLs, metadata, favoritos, history) pero el playback es responsabilidad de Flutter con `just_audio`.

- **Streaming radio:** Node consulta Radio Browser API → devuelve URLs → Flutter abre el stream directamente
- **Archivos locales:** Flutter accede al filesystem del dispositivo y reproduce con `just_audio`
- **YouTube:** Node actúa de proxy hacia Invidious (self-hosted en Docker). Flutter nunca toca YouTube directo.
  ```
  Flutter → POST /youtube/resolve { "url": "..." }
  Node    → GET http://invidious:3000/api/v1/streams/{id}
  Node    → devuelve URLs de stream al cliente
  Flutter → just_audio.play(streamUrl) + visualizador activo
  ```

### 5. Visualizador de espectro
El visualizador (barritas al ritmo del sonido) **requiere datos de frecuencia en tiempo real (FFT)**. Esto solo es viable si Flutter reproduce el audio:

- `just_audio` expone `AudioPlayer.processedAudioSampleStream` con samples crudos
- Se pasa por un FFT (Fast Fourier Transform) para obtener buckets de frecuencia
- Cada bucket se mapea a una barrita con `CustomPainter` o `AnimatedContainer`
- La respuesta es nativa, sin lag, sin depender de WebSocket

Si Node reprodujera, Flutter tendría que pedirle los datos por WebSocket → lag innecesario y complejidad extra. **Flutter reproduce = visualizador fluido.**

### 6. Animaciones del splash
Flutter tiene `AnimatedContainer`, `OpacityTransition`, y `AnimationController`. La barra de progreso, el glow del texto y el fade-in se replican fielmente con widgets nativos.

---

## Tecnologías Recomendadas

### Backend (Node.js)
| Paquete | Uso |
|---------|-----|
| `@nestjs/*` | Framework principal |
| `@prisma/client` | ORM + PostgreSQL |
| `class-validator` / `class-transformer` | DTOs y validación |
| `rxjs` | Streams (eventos del vehículo) |
| `winston` | Logging (reemplaza `logging`) |

### Frontend (Flutter)
| Paquete | Uso |
|---------|-----|
| `go_router` | Navegación |
| `flutter_riverpod` | State management |
| `dio` | HTTP client |
| `web_socket_channel` | WebSocket |
| `just_audio` + `audio_service` | Playback de audio/radio/local/YouTube (vía URL resuelta por Node) |
| `audio_visualizer` / `flutter_bass` | Visualizador de espectro (barritas al ritmo del sonido) |
| `video_player` | Video del splash |
| `google_fonts` / `flutter_svg` | Tipografía e iconos |
| `shared_preferences` | Settings locales (caché) |

---

## Lo que NO se porta (o se hace diferente)

| Python/QML | Destino | Razón |
|------------|---------|-------|
| `QmlBridge` | Eliminado | Flutter habla directo a la API |
| `QQmlApplicationEngine` | Eliminado | Flutter es self-contained |
| `sys.path.insert()` discovery | Eliminada | Módulos NestJS declarativos en `app.module.ts` |
| VLC en Python | `just_audio` en Flutter | El playback es responsabilidad del cliente + visualizador FFT |
| Radio Browser API (desde Python) | `RadioModule` en NestJS | Node hace la petición y devuelve URLs limpias a Flutter |
| `pyproject.toml` / `requirements.txt` | `package.json` + `pubspec.yaml` | Gestores nativos de cada stack |
| `systemd` service files (Python) | systemd para Node.js process | El backend se ejecuta como servicio systemd |

### Nota: Invidious (YouTube) — pendiente

Invidious se incluye en el `docker-compose.yml` pero **no forma parte de las fases iniciales**.
Se activa cuando se implemente la integración con YouTube. Flutter nunca se conecta a YouTube directo;
Node actúa de proxy: recibe una URL de YouTube → consulta Invidious interno → devuelve URLs de stream
que Flutter puede reproducir con `just_audio`.

```
Futuro endpoint en NestJS:
  POST /youtube/resolve   { "url": "https://youtube.com/watch?v=..." }
  → GET http://invidious:3000/api/v1/streams/{id}
  → devuelve { "audio": ["url_m4a", "url_webm"], "video": [...] }
```

---

## Scripts de Desarrollo

### Backend
```bash
cd backend
npm install
npx prisma generate
npx prisma migrate dev
npm run start:dev    # NestJS watch mode en :3000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d linux   # O android/emulator/ios
```

### Docker Compose (desarrollo)
```yaml
version: '3.8'
services:
  postgres:
    image: postgres:16-alpine
    ports: ["5432:5432"]
    volumes: [pgdata:/var/lib/postgresql/data]
    environment:
      POSTGRES_USER: hiluxos
      POSTGRES_PASSWORD: hiluxos_dev
      POSTGRES_DB: hiluxos

  backend:
    build: ./backend
    ports: ["3000:3000"]
    volumes: ["./backend/src:/app/src"]
    environment:
      - DATABASE_URL=postgresql://hiluxos:hiluxos_dev@postgres:5432/hiluxos
      - GPIO_REAL=false
    depends_on: [postgres]

  # Invidious (YouTube API self-hosted) — para fase de YouTube
  invidious:
    image: ghcr.io/iv-org/invidious:latest
    ports: ["3001:3000"]
    environment:
      INVIDIOUS_DB__DEFAULT__HOST: postgres
      INVIDIOUS_DB__DEFAULT__NAME: hiluxos_invidious
      INVIDIOUS_DB__DEFAULT__USER: hiluxos
      INVIDIOUS_DB__DEFAULT__PASSWORD: hiluxos_dev
    depends_on: [postgres]

  # Opcional: Python voice service (futuro)
  voice:
    build: ./voice-service
    ports: ["5000:5000"]

volumes:
  pgdata:
```

Nota: Invidious se incluye en el compose pero **no se usa en las fases iniciales**.
     Se activa cuando se implemente la integración con YouTube.

---

---

## Estado Actual: Implementación Inicial (2026-07-23)

### ✅ Completado: Estructura Flutter Base

Se ha creado el proyecto Flutter en `frontend/` con:

**Archivos creados:**
- `lib/main.dart` — Entry point con ProviderScope y MaterialApp.router
- `lib/core/theme/app_theme.dart` — Tema oscuro con colores idénticos al QML (`#0d1117`, `#58a6ff`, etc.)
- `lib/layout/navigation_router.dart` — go_router con rutas: `/splash`, `/`, `/radio`, `/media`, `/settings`
- `lib/layout/app_shell.dart` — Scaffold con NavigationBar inferior (Home, Radio, Media, Ajustes)
- `lib/features/splash/splash_screen.dart` — Animación completa: fade in imagen, slide up, glow logo, progress bar 4s
- `lib/features/home/home_screen.dart` — Dashboard grid 3x2 con DashboardCards interactivos
- `lib/widgets/dashboard_card.dart` — Card reutilizable con icono, título, valor, color custom
- `lib/features/radio/radio_screen.dart` — Radio mockup con búsqueda, playback controls, tabs (search/favorites/history)
- `lib/widgets/spectrum_visualizer.dart` — Visualizador FFT con 32 barras animadas (gradiente azul)
- `lib/features/media/media_screen.dart` — Media player placeholder
- `lib/features/settings/settings_screen.dart` — Settings con sliders (brillo/volumen), switches, status tiles
- `pubspec.yaml` — Dependencias: go_router, flutter_riverpod, dio, just_audio, audio_service, google_fonts
- `test/widget_test.dart` — Tests básicos de navegación

**Para ejecutar en tu máquina real:**
```bash
cd frontend
flutter pub get
flutter run -d linux  # O android/ios según tu dispositivo
```

### 📋 Pendiente: Backend NestJS

El backend aún no se ha implementado. Cuando esté listo, actualizar:
- `radio_screen.dart` para llamar a `GET /radio/stations/search?q=` en vez de mock data
- Agregar WebSocket service para estado en tiempo real (vehicle signals)
- Integrar just_audio con URLs reales del backend

---

## Resumen de Equivalencias

| Concepto Original | Nueva Implementación |
|-------------------|---------------------|
| `main.py` entry point | `backend/src/main.ts` + `frontend/lib/main.dart` (separados) |
| `EventBus` pub/sub | WebSocket Gateway (`@nestjs/websockets`) |
| `AppManager.discover_apps()` | Módulos NestJS en `app.module.ts` |
| `QmlBridge` signals/slots | API REST + WebSocket events |
| QML `StackView.push/pop` | `go_router` navigation |
| QML `Signal`/`Slot` | Riverpod `StateNotifier` + API calls |
| QML `Component` dynamic loading | Flutter route definitions (static) |
| `manifest.json` discovery | NestJS `@Module()` decorators |
| Python `logging` | `winston` o `pino` |
| PySide6 `QApplication` | Flutter `runApp()` |
| QML `Timer`/`Animation` | Flutter `Timer.periodic` + `AnimatedWidget` |

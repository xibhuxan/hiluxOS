# Backlog de features — hiluxOS

> Lista viva de ideas y tareas. Marca con `[x]` lo hecho (con fecha) y mueve el
> detalle a `STATUS.md`. Añade libremente — hay espacio de sobra; luego hay
> tiempo de quitar. Orden aproximado por valor/esfuerzo, no estricto.

**Leyenda:** ✅ hecho · 🚧 en curso · ⬜ pendiente · ⏸️ aparcado

---

## Infotainment / audio

- ⬜ **Vídeo (media_kit)** — videoclips, películas, series. Análisis ya hecho en
  `ROADMAP-MEDIA.md` (idea 2, aparcada): backend casi no cambia (ffprobe +
  Range ya sirven el archivo), el coste es el toolchain nativo (libmpv, +30-40MB
  de libs). **Empezar por spike de toolchain** antes de diseñar.
- ✅ **Bluetooth Media (A2DP/AVRCP)** — 2026-09-08. Audio del móvil al sistema.
  Módulo HAL `btmedia` (driver abstracto + Mock + Bluez real vía bluetoothctl,
  degrada a available:false sin adaptador). REST `/api/system/btmedia` (GET
  estado, POST play/pause/next/previous, PUT volume). Pantalla `/btmedia`
  (tile "Bluetooth"): now-playing con progreso, controles táctiles, volumen,
  estados "Sin dispositivo" / "Bluetooth no disponible" con Reintentar.
  **Limitación**: el routing A2DP real se valida en la Pi.
- ⬜ **YouTube/Invidious proxy** — `POST /youtube/resolve` (pendiente explícito
  del roadmap). Buscar y streamear vídeos/audio de YouTube vía una instancia
  Invidious, sin anuncios ni API key.
- ⬜ **Spotify Connect** — recibir audio de Spotify (librespot). Requiere cuenta
  premium; el móvil actúa de mando.
- ⬜ **CarPlay / Android Auto (open)** — proyección del teléfono (OpenAuto /
  headunit). Muy ambicioso; reevaluar.
- ⬜ **Radio DAB+** — si hay sintonizador USB DAB en la Pi; complementa la radio
  por internet actual.

## Navegación / coche

- ✅ **Navegación / Mapas** — 2026-09-08. Módulo `maps` (proxy Nominatim
  geocode/reverse + OSRM route, instrucciones en español). Pantalla `/maps`
  (tile "Navegación") con **flutter_map** (tiles OSM): pan/zoom, marcador,
  búsqueda de destino, "Cómo llegar" con polyline + distancia/duración.
  Preparado para tiles offline (MBTiles) en el futuro.
- ⬜ **Cámara trasera** — vista de aparcamiento al dar marcha atrás (HAL:
  trigger por GPIO/CAN + captura V4L2/USB). Overlay de guías de distancia.
- ⬜ **Sensores de aparcamiento** — distancia a obstáculos (ultrasonidos vía
  ESP32/GPIO), visualización en el diagrama del coche.
- ⬜ **TPMS** — presión/temperatura de neumáticos (sensores BLE o CAN).
- ⬜ **Diagnosis OBD-II real** — cuando haya adaptador ELM327: códigos de error
  (DTC), lectura/borrado, datos en vivo. Hoy el `/obd` está deshabilitado
  (ADR-0002).
- ⬜ **Grabación de rutas / tracklog** — GPX de trayectos, estadísticas de
  viaje (consumo, distancia, tiempo).
- ⬜ **Modo off-road** — inclinómetro (IMU), altitud, brújula, coordenadas.

## Conectividad / info

- ✅ **Clima** — 2026-09-08. Módulo `weather` (Open-Meteo, gratis sin key):
  GET `/api/weather` (actual) y `/api/weather/forecast`, ubicación por
  `?city=`/`?lat=&lon=` con default en settings (`weather.location`, sembrada
  "Madrid"). Pantalla `/weather` (tile "Clima"): condición actual grande,
  humedad/viento, previsión horaria y diaria, iconos por weather_code WMO.
- ⬜ **Notificaciones del móvil** — espejo de notificaciones Android
  (kdeconnect / notificaciones vía BT MAP).
- ⬜ **Llamadas manos libres (HFP)** — contestar/colgar, agenda, micrófono y
  altavoces del coche vía Bluetooth HFP.
- ⬜ **Mensajería** — lectura de SMS/WhatsApp por voz (TTS) + dictado (STT).
- ⬜ **Hotspot del coche** — compartir la conexión del sistema como AP WiFi.
- ⬜ **Tráfico en vivo** — incidencias y estado del tráfico sobre el mapa.

## Voz / inteligencia

- ✅ **Asistente de voz** (2026-09-08) — pipeline completo: motor de intenciones
  NLU en español (navegación, clima, media, radio, llamadas, climatización,
  volumen, estado, ayuda), HAL de voz con driver `mock` (determinista, sin mic)
  y `vosk` (Vosk ASR + Piper TTS, env `VOICE_DRIVER`), REST `/api/voice`
  (`GET` estado, `POST /command`, `POST /listen` PCM, `POST /speak` WAV,
  `GET/DELETE /history`) + eventos WS `voice`/`voice_status`. Pantalla
  `/voice` (tile "Asistente") con push-to-talk animado, historial de
  conversación, entrada de texto y reproducción TTS vía audioplayers.
  ⏳ Pendiente hardware: micro + modelo Vosk real y wake-word en la Pi.
- ⬜ **Comandos de voz del vehículo** — "abre las ventanillas", "enciende las
  largas" sobre el HAL Vehicle (conectar intents `vehicle_*` al `VehicleService`).
- ⬜ **Acciones reales del asistente** — que los intents `navigate`/`weather`/
  `media`/`radio` ejecuten sobre sus servicios (hoy devuelven la confirmación
  hablada; la acción concreta se enchufa a cada módulo).
- ⬜ **Wake-word** — "Hey Hilux" (openWakeWord/Porcupine) para activación manos
  libres; hoy es push-to-talk.

## Sistema / plataforma

- ⬜ **Multi-perfil de conductor** — presets por persona (EQ, volumen, radio,
  asiento/espejos si hay actuadores), cambio rápido.
- ⬜ **Arranque rápido / suspend-to-RAM** — reducir el tiempo de arranque en la
  Pi (análisis de boot, servicios mínimos, splash temprano).
- ⬜ **Actualización A/B** — particiones duales para OTA sin riesgo de brick.
- ⬜ **Modo noche / atenuación automática** — brillo según hora/luz ambiental.
- ⬜ **Gestión de energía de aparcamiento** — deep-sleep con wake por CAN/GPIO,
  monitorización de batería para no agotarla.
- ⬜ **Integración con domótica** — abrir garaje, luces de casa (Home Assistant).

---

### Implementadas (esta tanda, 2026-09-08)
- Clima · Navegación/Mapas · Bluetooth Media · **Asistente de voz** — detalle en `STATUS.md`.

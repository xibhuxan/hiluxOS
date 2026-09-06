# Roadmap Media — hiluxOS

Fecha: 2026-09-01 · Análisis de viabilidad de las tres ideas propuestas para
Media (carpetas configurables, reproducción de vídeo, modo pantalla completa).
Aprobado con el usuario: **hacer 1 y 3 ahora; 2 (vídeo) aparcado**.

| # | Idea | Estado |
|---|------|--------|
| 1 | Carpetas configurables en BD | ✅ Hecha — detalle en [`STATUS.md`](./STATUS.md) (Fase 4) |
| 2 | Vídeo (media_kit) | ⏸️ Aparcada — análisis abajo |
| 3 | Fullscreen táctil compartido | ✅ Hecha — detalle en [`STATUS.md`](./STATUS.md) (Fase 4) |

> Las dos ideas hechas se documentan con su detalle completo en
> [`STATUS.md`](./STATUS.md); aquí solo queda lo que sigue siendo relevante.

---

## Idea 2 — Reproducción de vídeo (vídeoclips, películas, series) ⏸️ APARCADA

**Objetivo:** indexar y reproducir archivos de vídeo además de audio.

**Viabilidad: media.** El problema no es el backend ni la UI, sino el motor de reproducción:
- `audioplayers` es **solo audio**. Reproducir vídeo en Flutter/Linux exige `media_kit` (libmpv), que sí soporta Linux ARM (Raspberry Pi) y GPU accel, PERO:
  - Requiere `sudo apt install libmpv-dev mpv` en la Pi y que `install-pi.sh` valide la dependencia (el instalador ya valida librerías y muere si faltan).
  - Los paquetes nativos (`media_kit_libs_video`) engordan el bundle UI (~30-40MB).
  - `flutter build linux` debe compilar/linkear los libs — hay que validar toolchain primero (spike de 30 min: `flutter pub add media_kit media_kit_video media_kit_libs_video` + `flutter build linux --release`).
- El backend casi no cambia: ffprobe ya probea cualquier archivo (solo añadir extensiones `.mp4/.mkv/.webm/.avi` y un campo `kind: audio|video` derivable de `stream_disposition`, que ya usamos para el art). `GET /media/stream/:id` ya sirve el archivo tal cual — mpv lo reproduciría vía HTTP Range.
- `SpectrumService` seguiría funcionando para vídeo (analiza el audio del mismo stream), aunque el espectro sobre vídeo es redundante (la imagen ya llena la pantalla).

**Decisión del usuario (2026-09-01):** dejar quieto. Reevaluar más adelante; si
se retoma, empezar por el spike de toolchain antes de diseñar la feature.


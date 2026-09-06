# Roadmap Media — hiluxOS

Fecha: 2026-09-01 · Análisis de viabilidad de las tres ideas propuestas para Media (carpetas configurables, reproducción de vídeo, modo pantalla completa). Aprobado con el usuario: **hacer 1 y 3 ahora; 2 (vídeo) aparcado**.

---

## Idea 1 — Carpetas configurables persistidas en BD ✅ (hecha)

**Objetivo:** el raíl de carpetas deja de ser un único `MEDIA_DIR` fijo del `.env` y pasa a ser una lista de rutas guardadas en PostgreSQL, gestionables desde la UI (añadir/eliminar), con indicación de rutas no disponibles ("missing") en disco.

**Viabilidad: alta.** Sin dependencias nuevas. Todo el trabajo cabe en el stack actual (Prisma + NestJS + Flutter).

**Diseño (implementado):**
- Nueva tabla Prisma `MediaFolder` — `{ id uuid, path unique, createdAt }` con migración `20260905171213_add_media_folders`; el `label` se calcula como basename en el DTO (no se persiste).
- `MediaFoldersService` (backend): `list()` (con `exists: fs.existsSync`), `add(path)` (valida absoluto, normaliza con `path.resolve`, rechaza duplicados), `remove(id)` (purga los tracks del índice cuya ruta cae bajo esa carpeta). Seed inicial: el `MEDIA_DIR` del `.env` se inserta **una sola vez** (guardado con el flag `Setting` `media.folders.seeded`); una vez sembrado (o eliminado por el usuario), no vuelve a insertarse nunca — una tabla vacía significa "el usuario quitó todas las carpetas", no "volver a sembrar". **Fix 2026-09-05**: el seed original re-sembraba `MEDIA_DIR` en cada listado con tabla vacía, resucitando la carpeta demo borrada (y el re-escaneo devolvía sus tracks); además `scanRoots()` hacía fallback a `MEDIA_DIR` con tabla vacía. Ahora el seed es one-shot y `scanRoots()` devuelve `[]` sin throw.
- API: `GET /media/folders`, `POST /media/folders {path}`, `DELETE /media/folders/:id`.
- Scanner multi-carpeta: `scan()` itera todas las `MediaFolder` (no solo `MEDIA_DIR`); carpetas que no existen en disco → `walk()` devuelve vacío (sin crash), pero sus filas quedan en la BD para cuando vuelvan.
- Flutter: modelo `MediaFolder`, provider con `loadFolders/addFolder/removeFolder`, raíl "Carpetas" con botón **＋ Añadir** (diálogo con `TextField` → `VirtualKeypad` sale gratis), tiles con ⚠️ + "no disponible" cuando `exists == false` (tap → SnackBar explicativo), y "Quitar" (delete) con confirmación vía diálogo.
- `Track.relPath` (usado por el árbol de carpetas) ahora se calcula contra el mejor prefijo de las carpetas configuradas (antes: solo `MEDIA_DIR`).

**Notas de diseño:**
- Al eliminar una carpeta, sus tracks se purgan del índice (mismos semantics que un scan que los encuentra desaparecidos).
- Carpetas solapadas (nested) están permitidas — `Track.path` es unique por ruta absoluta, y el upsert es idempotente.
- Un track bajo dos carpetas solapadas aparece en ambas en el rail (cuenta por carpeta exacta igual que antes, solo que ahora puede pertenecer a más de una).
- `MEDIA_DIR` sigue existiendo: es la carpeta seed inicial (una sola vez, flag `media.folders.seeded`); ya no es fallback del scanner — tabla vacía → scan no-op, sin tocar `MEDIA_DIR`.

## Idea 2 — Reproducción de vídeo (vídeoclips, películas, series) ⏸️ APARCADA

**Objetivo:** indexar y reproducir archivos de vídeo además de audio.

**Viabilidad: media.** El problema no es el backend ni la UI, sino el motor de reproducción:
- `audioplayers` es **solo audio**. Reproducir vídeo en Flutter/Linux exige `media_kit` (libmpv), que sí soporta Linux ARM (Raspberry Pi) y GPU accel, PERO:
  - Requiere `sudo apt install libmpv-dev mpv` en la Pi y que `install-pi.sh` valide la dependencia (el instalador ya valida librerías y muere si faltan).
  - Los paquetes nativos (`media_kit_libs_video`) engordan el bundle UI (~30-40MB).
  - `flutter build linux` debe compilar/linkear los libs — hay que validar toolchain primero (spike de 30 min: `flutter pub add media_kit media_kit_video media_kit_libs_video` + `flutter build linux --release`).
- El backend casi no cambia: ffprobe ya probea cualquier archivo (solo añadir extensiones `.mp4/.mkv/.webm/.avi` y un campo `kind: audio|video` derivable de `stream_disposition`, que ya usamos para el art). `GET /media/stream/:id` ya sirve el archivo tal cual — mpv lo reproduciría vía HTTP Range.
- `SpectrumService` seguiría funcionando para vídeo (analiza el audio del mismo stream), aunque el espectro sobre vídeo es redundante (la imagen ya llena la pantalla).

**Decisión del usuario (2026-09-01):** dejar quieto. Reevaluar más adelante; si se retoma, empezar por el spike de toolchain antes de diseñar la feature.

---

## Idea 3 — Modo pantalla completa táctil compartido ✅ (hecha)

**Objetivo:** pantalla completa ocupada por visualizador/portada (Media álbum/espectro, Radio espectro), entrar tocando un botón "expandir", salir tocando en cualquier parte de la pantalla.

**Viabilidad: alta.** Es un overlay dentro del `Stack` del `AppShell` (encima de status panel, panels, toasts — por debajo del teclado, que no interfiere porque no hay campos de texto). El `SpectrumVisualizer` es un widget normal y ya funciona a pantalla completa; el álbum art escala a `BoxFit.contain` con marco de disco de vinilo; el player vive en Riverpod global, así que la reproducción sigue su curso detrás del overlay.

**Diseño (implementado):**
- `app/lib/layout/fullscreen_host.dart`: `FullscreenHost` es un `StatefulWidget` que recibe un `builder(context, exit)` — el contenido lo construye cada pantalla con acceso al callback de salida. Tap en cualquier parte → `exit()`. Se monta en el `Stack` del shell (segundo elemento, sobre `widget.child`).
- `AppShellState` expone `enterFullscreen(Widget Function(BuildContext, VoidCallback) builder)`; cualquier pantalla del app puede llamarlo.
- Media: botón expandir (icono `fullscreen`, tooltip "Pantalla completa") en la fila de controles junto al selector de vista. Contenido: modo álbum → portada con efecto disco de vinilo (rotación lenta mientras suena, marco negro, brillo especular sutil), modo espectro → `SpectrumVisualizer(active: state.isPlaying, showStyleButton: true)` a pantalla completa.
- Radio: botón expandir junto al selector de estilos del visualizador.
- "Tap para salir": el contenido fullscreen está envuelto en un `GestureDetector(onTap: exit)`, sin controles — solo contenido. v1 simple, como pidió el usuario.

---

## Orden de ejecución

| # | Idea | Estado |
|---|------|--------|
| 1 | Carpetas en BD + missing icon | ✅ Hecho — ver arriba |
| 2 | Vídeo (media_kit) | ⏸️ Aparcado |
| 3 | Fullscreen compartido | ✅ Hecho — ver arriba |

Comits separados por idea, tests en cada paso (backend unit + e2e, Flutter widget).


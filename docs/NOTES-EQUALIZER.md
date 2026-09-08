# Notas — Ecualizador / Audio DSP

> **✅ IMPLEMENTADO 2026-09-08** — Ecualizador gráfico de 8 bandas completo
> (backend HAL + REST + persistencia, UI Flutter con curva de respuesta,
> presets y balance). Driver real PipeWire filter-chain + mock por defecto.
> 14 tests de backend, 5 de pantalla; analyze limpio. Este documento registra
> el diseño y las decisiones.

## Objetivo

Pantalla de ecualizador **completa, bonita, funcional y potente** — un EQ
gráfico tipo coche (8 bandas) que se aplica a todo el audio del sistema, con
presets, balance estéreo y loudness, persistido entre reinicios.

## Arquitectura

### Backend — `backend/src/modules/equalizer/` (HAL, como `power`/`vehicle`)

Driver abstracto `EqualizerDriver` con sustitución por config
(`EQ_DRIVER=mock|pipewire`, factory en `equalizer.module.ts`, token
`EQ_DRIVER`). Dos implementaciones:

- **`MockEqualizerDriver`** (por defecto): estado en memoria, determinista,
  sin I/O. Tests y desarrollo.
- **`PipeWireEqualizerDriver`**: aplica el EQ de verdad creando un nodo
  **filter-chain** de PipeWire (`pw-cli create-node adapter` con
  `factory.name=support.filter-chain`). Cada banda → un biquad `bq_peaking`
  (Freq/Q/Gain); loudness → un `bq_lowshelf`; balance → un `channelmix`
  (ganancia por canal). El nodo se marca como sink por defecto
  (`wpctl set-default`) para que todo el audio lo atraviese. **Degrada a
  `available:false`** si no hay daemon PipeWire (igual que `RpiPowerDriver`
  sin `vcgencmd`), y los setters son no-op hasta reconexión.

> **Decisión clave (host vs Pi):** en el host de desarrollo `pw-cli
> load-module` con el módulo filter-chain no crea el nodo de forma fiable (lo
> hace `create-node`, pero el factory filter-chain necesita el módulo cargado
> o un session manager). La validación fina del routing se hace en la Pi real;
> la UI, el modelo, la persistencia y los tests son 100% reales y completos
> contra el mock. Esto es coherente con el enfoque HAL mock-first del proyecto
> (ADR-0002): la integración de host frágil no bloquea la feature.

### Persistencia

El estado y los presets de usuario se guardan en la tabla `settings` (Prisma,
key/value JSON): `equalizer.state` y `equalizer.customPresets`. Se restaura al
arrancar (`onModuleInit`); la persistencia es *best-effort* (una DB caída no
impide funcionar con valores por defecto).

### Modelo

- **8 bandas fijas** octava-espaciadas: 60, 120, 250, 500, 1k, 2k, 4k, 8k Hz.
- **Ganancia** por banda, ±12 dB (clamp).
- **Balance** estéreo en [-1, 1].
- **Loudness** (refuerzo de graves a bajo volumen).
- **Presets** built-in (Plano, Rock, Pop, Bass Boost, Vocal, Graves coche) +
  presets de usuario que pueden solapar/borrar. Los built-in no se borran.

### REST (`/api/system/equalizer`)

| Método | Ruta | Acción |
|---|---|---|
| GET | `/` | Estado completo (enabled, bands, balance, loudness, activePreset) |
| GET | `/capabilities` | available, bandCount, minGain/maxGain, freqs |
| PUT | `/` | Actualización parcial (enabled/gains/balance/loudness) |
| PUT | `/band/:index` | Ganancia de una banda (400 si índice fuera de rango) |
| POST | `/reset` | Curva plana |
| GET | `/presets` | Lista built-in + usuario |
| POST | `/presets/:name/apply` | Aplica un preset (404 si no existe) |
| PUT | `/presets/:name` | Crea/sobrescribe un preset de usuario |
| DELETE | `/presets/:name` | Borra un preset de usuario (built-in protegidos) |

## Frontend — `app/lib/features/equalizer/`

- **`equalizer_provider.dart`** — `EqualizerNotifier` (StateNotifier) con
  `EqualizerState` inmutable, parsing JSON, y `setBandLive` con **throttle
  leader+trailing-queue** (mismo patrón que `AudioNotifier.setVolumeLive`) para
  que el arrastre de sliders no inunde el backend.
- **`equalizer_screen.dart`** — la pantalla:
  - **Header**: switch maestro Activado/Desactivado, botón reset (plano),
    botón Guardar (diálogo de nombre de preset).
  - **PresetRow**: chips horizontales; el activo lleva el `accentGradient`.
  - **BandPanel**: 8 sliders verticales (RotatedBox) con la **curva de
    respuesta pintada detrás** (`_ResponseCurvePainter`, spline Catmull-Rom →
    Bézier con relleno degradado y línea de cero). Cada banda muestra la
    ganancia encima y la frecuencia debajo.
  - **Footer**: slider de balance (L/R con etiqueta Centro/Izq/Der) y toggle
    Loudness.
  - Estado degradado "Audio no disponible" cuando `available:false`.
- Integración: ruta `/equalizer`, tile "Ecualizador" en el cajón, título en
  `shell_title.dart`.

## Tests

- **Backend** (`equalizer.service.spec.ts`, 14 tests): estado inicial plano,
  capabilities, update con clamp de ganancias/balance, persistencia, setBand
  marca custom, reset, listado/apply/save/delete de presets, protección de
  built-ins, restore en `onModuleInit`, y supervivencia a DB caída.
- **Flutter** (`equalizer_screen_test.dart`, 5 tests): render de 8 bandas y
  presets, tap de preset lo aplica, switch de enable, botón reset, y estado
  "no disponible".

## Pendiente / futuro

- Validar el routing del `PipeWireEqualizerDriver` en la Pi (el routing fino
  del filter-chain es específico del host; puede requerir WirePlumber o un
  drop-in config). Considerar `pw-cli set-param` para re-ajustar biquads en
  sitio en lugar de recrear el nodo (eliminaría el click de audio al mover).
- Posible VU-meter / analizador de espectro en vivo sobre la curva.

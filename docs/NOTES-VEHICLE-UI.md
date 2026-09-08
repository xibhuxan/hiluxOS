# Notas de trabajo — Vehículo: UI v2 (pestañas, gauges, ventanillas en vivo)

> **✅ IMPLEMENTADO 2026-09-08** — Los 3 bugs y la pestaña "Coche" están hechos
> y commiteados en `feature/develop` (commits `ccb3430` toggle, `38bac65` gauge,
> `48c5947` ventanillas en vivo, `1c347bf` pestaña Coche). 332 tests (96 Flutter),
> analyze limpio. Este documento queda como registro del diagnóstico y las
> decisiones de diseño. Lo que sigue es el material original de la sesión.

> Documento de mano para la siguiente sesión. La app Vehículo (Fase 3) está
> terminada, en `feature/develop` con CI verde (327 tests: 135 unit + 101 e2e +
> 91 Flutter). Esto es el **feedback del usuario tras usarla en vivo** (2026-09-06)
> y el diagnóstico ya hecho con el código leído — no hay nada editado todavía.

## Feedback del usuario (3 puntos + 1 propuesta)

1. **Toggle Control⇄Dashboard casi inutilizable**: "solo funciona pisando
   encima de Dashboard, como que encima de Control no hay botón".
2. **Números del gauge mal puestos**: están "justo encima del centro de la
   aguja; deberían estar por debajo, ya que es km/h y rpm, pues debajo de esos".
3. **Ventanillas sin progreso en directo**: "solo se ve cuando está en la
   mitad y acabado" (quiere ver la barra moverse continuamente).
4. **Propuesta (le encanta la idea, pregunta "qué te parecería")**: una
   **tercera pestaña "Coche"** con el coche dibujado y todos los sistemas de
   forma interactiva y visual, que a futuro sustituya a Control.

## Diagnóstico exacto (código ya leído y verificado)

### Bug 1 — El toggle `_ModeToggle` está roto por diseño
`app/lib/features/vehicle/vehicle_screen.dart`, línea 116: cada segmento
construido por `segment()` hace `onTap: () => onChanged(!active)`. Estando
en Dashboard, el segmento Control tiene `active=false`, luego su tap emite
`onChanged(true)` = "dashboard=true" → **se queda en Dashboard**. La única
transición posible es Control→Dashboard; volver es imposible (por eso el
usuario siente que "encima de Control no hay botón"). Fix trivial: cada
segmento debe emitir **su propio valor**, no `!active`:

```dart
// segment() gana un parámetro `value` (lo que ese segmento representa):
onTap: () => onChanged(value)  // Control => false, Dashboard => true
```

### Bug 2 — Valor + unidad del gauge tapan el pivote de la aguja
`app/lib/features/vehicle/widgets/animated_gauge.dart` (build, líneas 65-92):
el `child` del `CustomPaint` es un `Center` con `Column` de `AnimatedCounter`
(número grande) + unidad. Ese bloque está **centrado exactamente donde la
aguja pivota** (`gauge_painter.dart` dibuja la aguja desde el centro), así
que número y aguja se solapan. Fix: desplazar el bloque número+unidad hacia
abajo del pivote — p. ej. envolver el Column en `Align(alignment:
Alignment(0, 0.55))` o un `Padding(top: radio*0.5)` calculado con
`LayoutBuilder`. La aguja queda apuntando por encima del número, como en un
cuadro real (el número va bajo el pivote).

### Bug 3 — Ventanillas: el backend ya anima, el UI descarta el movimiento
**El mock ya calcula posición continua**: `simulateWindow()`
(`backend/src/modules/vehicle/drivers/mock-vehicle.driver.ts`, ~líneas
193-216) devuelve `position` lineal con el reloj (viaje completo = 2 s,
`WINDOW_TRAVEL_PER_SECOND = 0.5`) + `moving: 'up'|'down'|null`. El problema
es la **frecuencia de poll**: `VehicleNotifier` hace `GET /vehicle` cada 3 s
(`interval = Duration(seconds: 3)` en `vehicle_provider.dart`), así que el
UI solo ve posición al pulsar, ~a mitad y al final. Además `WindowRow` usa
`AnimatedProgressBar` (tween 600 ms) que "filma" los saltos en vez del
movimiento continuo.

**Fix recomendado (coherente con mock-first)**: interpolar en vivo en el
widget. Cuando `moving != null`, el `WindowRow` anima su barra localmente
desde `position` hacia el destino (0 si `up`, 1 si `down`) a **0.5/s
exactos** (misma constante que el mock), con `Curves.linear`; el siguiente
poll resincroniza:
- Si el poll trae `moving != null` todavía: re-crear el tween desde la
  posición del poll (no desde la local) para no acumular drift.
- Si trae `moving == null`: fijarse al valor final del poll.
- Implementación: `WindowRow` pasa a StatefulWidget con
  `AnimationController` (2 s, lineal) o, mejor, un `Ticker` que sume
  `dt*0.5` a una posición local (permite resincronizar sin cortar el
  movimiento).
- Alternativa más simple (menos bonita): bajar el poll a 1 s mientras haya
  ventanilla en movimiento. No recomendada — multiplica requests.

### Propuesta 4 — Tercera pestaña "Coche" (visual, para sustituir a Control)
Diseño propuesto:
- Toggle de 3 segmentos: **Coche | Control | Dashboard** (mismo `_ModeToggle`
  arreglado, ahora con enum). `_VehicleTab { car, control, dashboard }` en
  `_VehicleScreenState` sustituye al `bool _dashboard`.
- Widget `CarDiagram` (nuevo, `widgets/car_diagram.dart`): vista cenital del
  Hilux con `CustomPainter` o CustomPaint + Positioned (cuerpo, 4 puertas, 4
  ventanillas, frontal). Interacción:
  - Tocar una **puerta** → `setDoor(id, !open)`; abierta se dibuja "batida"
    (rotada respecto a la bisagra) y en color warning.
  - Tocar una **ventanilla** → toggle subir/bajar/parar (`windowAction(id,
    …)`); el vidrio se dibuja con altura/opacity proporcional a `position`,
    animando en vivo con el mismo interpolador del fix 3 (extraerlo a un
    helper compartido, p. ej. `window_position_lerp.dart`).
  - **Intermitentes**: flechas en las esquinas que parpadean (reusar patrón
    de blink de `ClusterTelltaleRow`).
  - **Luces**: faros/halos encendidos según tipo (position=tenue,
    low=ámbar suave, high=azulado, fog=morado, aux=blanco).
  - **Cierre/alarma**: badge candado/escudo sobre el coche; motor: mantener
    `EngineButton` (o pill flotante START/STOP).
- La sustitución definitiva de Control se decide tras probarla; por ahora
  conviven las tres pestañas.

## Plan de ejecución (en orden, commits separados)

1. `fix(vehicle): toggle de modos emite el valor del segmento` (bug 1).
   Test: estando en Dashboard, tocar "Control" vuelve a Control (patrón fake
   de `vehicle_screen_test.dart`).
2. `fix(vehicle): número del gauge bajo el pivote de la aguja` (bug 2).
   Los tests de textos (`km/h`, `rpm`) siguen pasando.
3. `feat(vehicle): ventanillas con progreso en vivo` (bug 3). Test: fake con
   `moving: 'down'` + `pump(1 s)` avanza la barra (leer `FractionallySizedBox`
   widthFactor o exponer valor con una Key).
4. `feat(vehicle): pestaña Coche (diagrama interactivo)` (propuesta 4):
   enum de 3 estados + `car_diagram.dart`. Tests: presencia del coche, tap
   en puerta llama `setDoor` (fake captura llamada), el toggle de 3 cambia
   de modo.
5. `docs: STATUS` — nueva entrada tachada en "Pendientes" + conteos si
   cambian (recordar: hash de STATUS = último commit de **código**; el
   commit de docs va detrás, sin hash propio).

## Recordatorios del repo (de sesiones anteriores)

- Tests Flutter con animación infinita (blink): **nunca `pumpAndSettle`**;
  usar `pump(Duration)` acotado. Slivers: viewport grande
  (`tester.view.physicalSize = Size(1280, 2400)`, dpr 1.0).
- Editor limitado a 6000 chars/edición → trocear widgets en varios archivos
  (patrón ya usado: `control_widgets`, `control_tiles`, `window_door_rows`…).
- Backend dev: `cd backend && nohup npm run start:dev > /tmp/hilux-backend.log
  2>&1 &`; check `curl -s localhost:3000/api/health`; log
  `tail -f /tmp/hilux-backend.log`. (Estaba corriendo en la sesión previa.)
- Verificación en vivo de ventanillas: `curl -s localhost:3000/api/vehicle`
  repetido — el mock avanza la posición entre llamadas.
- Commits: `feat(vehicle): …`, `fix(vehicle): …`, `docs: …`; CI dispara en
  push a feature/develop (Backend ~1m15s, Flutter ~1m); docs-only no dispara
  (filtros `paths:`).
- Mock driver: **sin timers** — la posición es función pura del reloj
  (`windowEvents` guarda dirección+instante+origen; `simulateWindow`
  integra). El fix 3 es solo UI; no tocar el driver.
- `AnimatedProgressBar`/`AnimatedCounter` son widgets core compartidos por
  otras apps (power, media…): **no cambiarles el comportamiento global**;
  la interpolación de ventanilla va en su propio widget/helper.

## Archivos clave (rutas relativas a la raíz del repo)

- Toggle y estados: `app/lib/features/vehicle/vehicle_screen.dart`
  (`_ModeToggle` ~106-162, `bool _dashboard` línea 27)
- Números del gauge: `app/lib/features/vehicle/widgets/animated_gauge.dart`
  (build 65-92)
- Pintado del gauge (aguja pivota en el centro):
  `app/lib/features/vehicle/widgets/gauge_painter.dart`
- Ventanillas UI: `app/lib/features/vehicle/widgets/window_door_rows.dart`
  (`WindowRow` 10-61)
- Provider (poll 3 s): `app/lib/features/vehicle/vehicle_provider.dart`
  (`VehicleNotifier`, `interval`)
- Mock backend (constante de viaje):
  `backend/src/modules/vehicle/drivers/mock-vehicle.driver.ts`
  (`WINDOW_TRAVEL_PER_SECOND = 0.5`, `simulateWindow`)
- Tests de pantalla: `app/test/vehicle_screen_test.dart` (viewport grande +
  `pump` acotado)
- Colores: `app/lib/core/theme/colors.dart` (accent verde #3fb950, primary
  azul #58a6ff, warning ámbar #d29922, danger rojo #f85149, purple #bc8cff)



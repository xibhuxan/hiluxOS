import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../vehicle_provider.dart';
import 'car_diagram_painter.dart';
import 'window_position_lerp.dart';

/// Top-down interactive diagram of the Hilux (the "Coche" tab).
///
/// A CustomPainter draws the body, the four doors (open ones rotated on
/// their hinge), the four window glasses (height ∝ live position), the
/// lights (colour by type) and the turn signals (blinking corners). Doors
/// and windows are tappable: a door toggles open/closed, a window cycles
/// up/stop/down. Everything is the same `vehicleProvider` poll — the
/// painter just repaints on every snapshot / interpolated frame.
class CarDiagram extends ConsumerStatefulWidget {
  const CarDiagram({super.key, required this.snap});

  final VehicleSnapshot snap;

  @override
  ConsumerState<CarDiagram> createState() => _CarDiagramState();
}

class _CarDiagramState extends ConsumerState<CarDiagram>
    with TickerProviderStateMixin {
  /// Live interpolators, one per window id (1-based).
  final Map<int, WindowPositionLerp> _lerps = {};

  /// Blink clock for the turn signals (only ticking while one is active).
  Ticker? _blink;
  double _blinkPhase = 0;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant CarDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    // Windows: one lerp each, re-synced from the poll.
    for (final w in widget.snap.windows) {
      _lerps
          .putIfAbsent(
            w.id,
            () => WindowPositionLerp(
              vsync: this,
              onChanged: () => setState(() {}),
              position: w.position,
              moving: w.moving,
            ),
          )
          .sync(w.position, w.moving);
    }
    // Turn signals: a single blink ticker, only while any signal is on.
    final anySignal =
        widget.snap.turnLeft || widget.snap.turnRight || widget.snap.hazard;
    if (anySignal && _blink == null) {
      _blink = createTicker(_onBlink)..start();
    } else if (!anySignal && _blink != null) {
      _blink!.dispose();
      _blink = null;
    }
  }

  Duration _lastBlink = Duration.zero;
  void _onBlink(Duration elapsed) {
    final dt = (elapsed - _lastBlink).inMicroseconds / 1e6;
    _lastBlink = elapsed;
    // ~1.4 Hz square wave, like a real flasher relay.
    setState(() => _blinkPhase = (_blinkPhase + dt * 1.4) % 1.0);
  }

  bool get _blinkOn => _blinkPhase < 0.5;

  @override
  void dispose() {
    for (final l in _lerps.values) {
      l.dispose();
    }
    _blink?.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails d) {
    final box = context.findRenderObject() as RenderBox;
    final notifier = ref.read(vehicleProvider.notifier);
    final hit = hitTestCarDiagram(d.localPosition, box.size);
    if (hit == null) return;
    switch (hit) {
      case CarHit(:final doorId?):
        final door = widget.snap.doors.firstWhere((x) => x.id == doorId);
        notifier.setDoor(doorId, !door.open);
      case CarHit(:final windowId?):
        final w = widget.snap.windows.firstWhere((x) => x.id == windowId);
        // Cycle: stopped → down → stop; moving → stop.
        final action = w.moving == null ? (w.isClosed ? 'down' : 'up') : 'stop';
        notifier.windowAction(windowId, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final positions = {
      for (final e in _lerps.entries) e.key: e.value.position,
    };
    return GestureDetector(
      onTapUp: _onTapUp,
      child: CustomPaint(
        painter: CarDiagramPainter(
          snap: widget.snap,
          windowPositions: positions,
          blinkOn: _blinkOn,
        ),
      ),
    );
  }
}

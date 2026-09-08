import 'package:flutter/scheduler.dart';

// The constructor takes public named params (vsync/onChanged) that map to
// private fields — initializing formals can't do that, so silence the lint.
// ignore_for_file: prefer_initializing_formals

/// Window travel speed, in position units per second. Matches the mock
/// driver's WINDOW_TRAVEL_PER_SECOND (0.5 — full travel = 2 s) so the
/// client-side interpolation tracks the backend exactly.
const double kWindowTravelPerSecond = 0.5;

/// Interpolates a window's position locally while it moves. The backend poll
/// only samples every 3 s, so without this the UI would jump tap → mid →
/// end. A Ticker integrates `dt * kWindowTravelPerSecond` towards the
/// destination (1 for 'down', 0 for 'up'); each poll re-syncs from the
/// backend value so no drift accumulates.
///
/// Used by both the WindowRow bar and the CarDiagram glass. The host widget
/// (a TickerProvider) creates one per window, calls [sync] on every poll,
/// and [dispose]s it. [onChanged] is invoked on every interpolated frame so
/// the host can setState / repaint.
class WindowPositionLerp {
  WindowPositionLerp({
    required TickerProvider vsync,
    required void Function() onChanged,
    required double position,
    required String? moving,
  }) : _vsync = vsync, _onChanged = onChanged {
    sync(position, moving);
  }

  final TickerProvider _vsync;
  final void Function() _onChanged;

  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  /// Current (possibly interpolated) position, 0 (closed) … 1 (open).
  double position = 0;
  String? _moving;

  /// Poll arrived: re-sync from the backend position (no drift) and start /
  /// stop the ticker according to the fresh `moving` flag.
  void sync(double newPosition, String? moving) {
    position = newPosition;
    _moving = moving;
    if (moving != null) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void dispose() => _stopTicker();

  void _startTicker() {
    if (_ticker != null) return; // already running — keep the local position
    _lastTick = Duration.zero;
    _ticker = _vsync.createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final direction = _moving == 'down' ? 1.0 : -1.0;
    final next = (position + direction * dt * kWindowTravelPerSecond).clamp(0.0, 1.0);
    if (next != position) {
      position = next;
      _onChanged();
    }
  }
}

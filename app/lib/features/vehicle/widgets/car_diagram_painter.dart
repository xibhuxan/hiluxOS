import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../vehicle_provider.dart';

/// Which part of the car a tap landed on (exactly one id is set).
class CarHit {
  const CarHit.door(this.doorId) : windowId = null;
  const CarHit.window(this.windowId) : doorId = null;
  final int? doorId;
  final int? windowId;
}

/// Normalized geometry (0..1, x = across the car, y = front→back). Kept
/// module-level so both the painter and the hit test share it.
const _body = Rect.fromLTWH(0.16, 0.02, 0.68, 0.96);
const _hoodBottom = 0.16;
const _roof = Rect.fromLTWH(0.22, 0.28, 0.56, 0.44);
const _bedTop = 0.72;
const _windshield = Rect.fromLTWH(0.24, 0.22, 0.52, 0.06);
const _rearWindow = Rect.fromLTWH(0.24, 0.66, 0.52, 0.05);

/// Windows: 1 driver FL, 2 passenger FR, 3 rear-left, 4 rear-right. They sit
/// OUTBOARD of the doors (doors occupy 0.14..0.23 / 0.77..0.86) so a tap on
/// the glass doesn't hit the door first (doors are tested before windows).
/// The body spans x 0.16..0.84, so the glass pokes just past the sill — like
/// looking at the window from above with the door skin removed.
const _windowRects = {
  1: Rect.fromLTWH(0.10, 0.32, 0.07, 0.15),
  2: Rect.fromLTWH(0.83, 0.32, 0.07, 0.15),
  3: Rect.fromLTWH(0.10, 0.51, 0.07, 0.15),
  4: Rect.fromLTWH(0.83, 0.51, 0.07, 0.15),
};

/// Doors: 1 FL, 2 FR, 3 RL, 4 RR. `hinge` = the hinge edge (true = front /
/// top edge for the swing direction). Rects are the closed-door footprints.
class _Door {
  const _Door(this.id, this.rect, this.hingeAtFront);
  final int id;
  final Rect rect;
  final bool hingeAtFront;
}

const _doors = [
  _Door(1, Rect.fromLTWH(0.14, 0.30, 0.09, 0.20), true), // FL
  _Door(2, Rect.fromLTWH(0.77, 0.30, 0.09, 0.20), true), // FR
  _Door(3, Rect.fromLTWH(0.14, 0.50, 0.09, 0.20), false), // RL
  _Door(4, Rect.fromLTWH(0.77, 0.50, 0.09, 0.20), false), // RR
];

/// Converts a local offset + size into the car part under it, if any.
/// Windows (the outboard glass strips) are tested BEFORE doors: they sit at
/// the very edge and a closed door's footprint overlaps them — the glass is
/// the more specific target. An OPEN door's swing extends past the glass, so
/// a tap that lands on both means the glass (the swung door is visually
/// obvious and its own rect still works).
CarHit? hitTestCarDiagram(Offset local, Size size) {
  final p = Offset(local.dx / size.width, local.dy / size.height);
  for (final e in _windowRects.entries) {
    if (e.value.contains(p)) return CarHit.window(e.key);
  }
  for (final d in _doors) {
    final closed = d.rect;
    if (closed.contains(p)) return CarHit.door(d.id);
    // Swung-out (open) door: a wedge to the outside of the body.
    final swing = _swingRect(d);
    if (swing.contains(p)) return CarHit.door(d.id);
  }
  return null;
}

Rect _swingRect(_Door d) {
  // Open door sweeps outwards (away from the body centre) around the hinge.
  const out = 0.16; // how far it swings (normalized x)
  final left = d.id.isOdd; // doors 1 & 3 on the left
  final w = d.rect.width;
  if (left) {
    return Rect.fromLTWH(d.rect.left - out, d.rect.top, out + w, d.rect.height);
  }
  return Rect.fromLTWH(d.rect.right - w, d.rect.top, out + w, d.rect.height);
}

/// Paints the whole car. Repaints on every snapshot and every interpolated
/// window frame (the lerp setStates the host, which rebuilds the painter).
class CarDiagramPainter extends CustomPainter {
  CarDiagramPainter({
    required this.snap,
    required this.windowPositions,
    required this.blinkOn,
  });

  final VehicleSnapshot snap;
  final Map<int, double> windowPositions;
  final bool blinkOn;

  Offset _p(Offset n, Size s) => Offset(n.dx * s.width, n.dy * s.height);
  Rect _r(Rect n, Size s) =>
      Rect.fromLTWH(n.left * s.width, n.top * s.height, n.width * s.width, n.height * s.height);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBody(canvas, size);
    _paintLights(canvas, size);
    _paintSignals(canvas, size);
    for (final d in _doors) {
      _paintDoor(canvas, size, d);
    }
    _paintWindows(canvas, size);
  }

  void _paintBody(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.surfaceVariant;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.muted.withValues(alpha: 0.5);
    final body = _r(_body, size);
    final rr = RRect.fromRectAndRadius(body, Radius.circular(size.width * 0.12));
    canvas.drawRRect(rr, paint);
    canvas.drawRRect(rr, border);

    // Hood, roof (cabin) and bed separation lines.
    final line = Paint()
      ..strokeWidth = 1.5
      ..color = AppColors.muted.withValues(alpha: 0.35);
    canvas.drawLine(Offset(body.left, _hoodBottom * size.height),
        Offset(body.right, _hoodBottom * size.height), line);
    canvas.drawLine(Offset(body.left, _bedTop * size.height),
        Offset(body.right, _bedTop * size.height), line);

    // Roof / cabin.
    final roofPaint = Paint()..color = AppColors.surface.withValues(alpha: 0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(_roof, size), Radius.circular(size.width * 0.05)),
      roofPaint,
    );

    // Windshield + rear window (fixed glass).
    final glass = Paint()..color = AppColors.primary.withValues(alpha: 0.16);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(_windshield, size), const Radius.circular(4)), glass);
    canvas.drawRRect(
      RRect.fromRectAndRadius(_r(_rearWindow, size), const Radius.circular(4)), glass);
  }

  void _paintLights(Canvas canvas, Size size) {
    // Front headlights + rear taillights, colour by active light type.
    Color? front;
    if (snap.highBeams) {
      front = const Color(0xFFBBDDFF); // cool blue-white
    } else if (snap.lowBeams) {
      front = const Color(0xFFFFE08A); // warm amber
    } else if (snap.positionLights) {
      front = AppColors.muted;
    }
    final headY = _hoodBottom * size.height - size.height * 0.015;
    for (final x in [0.24, 0.76]) {
      final c = _p(Offset(x, headY / size.height), size);
      if (front != null) _glow(canvas, c, size.width * 0.035, front);
      // Always draw the lamp housing so the car reads as a car.
      canvas.drawCircle(c, size.width * 0.016,
          Paint()..color = front ?? AppColors.muted.withValues(alpha: 0.3));
    }
    // Fog lights (lower, purple-ish) and auxiliary (white bar on the roof).
    if (snap.fogLights) {
      for (final x in [0.30, 0.70]) {
        _glow(canvas, _p(Offset(x, 0.055), size), size.width * 0.022, const Color(0xFFC9A7F5));
      }
    }
    if (snap.auxiliaryLights) {
      _glow(canvas, _p(const Offset(0.5, 0.30), size), size.width * 0.05, Colors.white);
    }
    // Taillights glow red when any light is on.
    final tail = snap.positionLights || snap.lowBeams || snap.highBeams;
    for (final x in [0.22, 0.78]) {
      _glow(canvas, _p(Offset(x, 0.965), size), size.width * 0.02,
          tail ? AppColors.danger : AppColors.muted.withValues(alpha: 0.25));
    }
  }

  void _paintSignals(Canvas canvas, Size size) {
    if (!blinkOn) return; // flashers blink off on the dark phase
    final amber = AppColors.warning;
    void arrow(Offset c, bool left) {
      final s = size.width * 0.03;
      final path = Path();
      if (left) {
        path.moveTo(c.dx - s, c.dy);
        path.lineTo(c.dx, c.dy - s * 0.7);
        path.lineTo(c.dx, c.dy + s * 0.7);
      } else {
        path.moveTo(c.dx + s, c.dy);
        path.lineTo(c.dx, c.dy - s * 0.7);
        path.lineTo(c.dx, c.dy + s * 0.7);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = amber);
    }

    final leftOn = snap.turnLeft || snap.hazard;
    final rightOn = snap.turnRight || snap.hazard;
    if (leftOn) {
      arrow(_p(const Offset(0.10, 0.07), size), true); // front
      arrow(_p(const Offset(0.10, 0.93), size), true); // rear
    }
    if (rightOn) {
      arrow(_p(const Offset(0.90, 0.07), size), false); // front
      arrow(_p(const Offset(0.90, 0.93), size), false); // rear
    }
  }

  void _paintDoor(Canvas canvas, Size size, _Door d) {
    final door = snap.doors.firstWhere((x) => x.id == d.id,
        orElse: () => VehicleDoorInfo(id: d.id, label: '', open: false));
    final open = door.open;
    final base = Paint()
      ..color = open ? AppColors.warning : AppColors.surface.withValues(alpha: 0.9);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = open ? AppColors.warning : AppColors.muted.withValues(alpha: 0.4);

    if (!open) {
      final rr = RRect.fromRectAndRadius(_r(d.rect, size), const Radius.circular(4));
      canvas.drawRRect(rr, base);
      canvas.drawRRect(rr, border);
      return;
    }
    // Open: draw the door swung outwards around the hinge.
    canvas.save();
    final hingeY = d.hingeAtFront ? d.rect.top : d.rect.bottom;
    final hingeX = d.id.isOdd ? d.rect.right : d.rect.left; // hinge on body side
    final hinge = _p(Offset(hingeX, hingeY), size);
    canvas.translate(hinge.dx, hinge.dy);
    final swing = (d.id.isOdd ? -1 : 1) * (d.hingeAtFront ? 1 : -1) * 1.1; // ~63°
    canvas.rotate(swing);
    final w = d.rect.width * size.width;
    final h = d.rect.height * size.height;
    final rect = Rect.fromLTWH(d.id.isOdd ? -w : 0, d.hingeAtFront ? 0 : -h, w, h);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), base);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), border);
    canvas.restore();
  }

  void _paintWindows(Canvas canvas, Size size) {
    for (final e in _windowRects.entries) {
      final pos = (windowPositions[e.key] ?? 0).clamp(0.0, 1.0);
      final rect = _r(e.value, size);
      // Frame.
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.muted.withValues(alpha: 0.4),
      );
      // Glass: open windows drop the glass (it shrinks from the top), alpha
      // tracks how "open" it is.
      final glassH = rect.height * (1 - pos);
      if (glassH > 0.5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, rect.top, rect.width, glassH),
            const Radius.circular(3),
          ),
          Paint()..color = AppColors.primary.withValues(alpha: 0.25 + 0.25 * (1 - pos)),
        );
      }
    }
  }

  void _glow(Canvas canvas, Offset c, double r, Color color) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(c, r * 0.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(CarDiagramPainter old) => true; // live lerp + blink
}

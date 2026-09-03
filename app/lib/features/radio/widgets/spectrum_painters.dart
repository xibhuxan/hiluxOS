import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../visualizer_style.dart';

/// Shared, repaint-driven frame of spectrum data.
///
/// The [SpectrumVisualizer] ticker is the only writer: each tick it runs the
/// winamp-style peak-hold + exponential decay smoothing over the latest
/// backend bands (or pseudo data) and calls [update], which notifies the
/// painters that were constructed with `repaint: frame`. This means bar
/// animation NEVER rebuilds the widget tree — only the canvas is repainted
/// (the high-performance pattern recommended by FFT/visualizer literature).
class SpectrumFrame extends ChangeNotifier {
  List<double> bars;
  List<double> peaks;

  /// Monotonic animation phase (seconds) used by the wave/circle styles to
  /// add motion on top of the spectrum data.
  double phase = 0;

  /// Raw backend band values (no frontend smoothing) for the debug view.
  List<double>? raw;

  /// Real measured updates-per-second of backend data (for debug). 0 while
  /// no real data arrives.
  double realUps = 0;

  /// How many times per second the band VALUES actually changed (debug).
  /// Distinct from [realUps]: backend may push many identical frames.
  double contentUps = 0;

  /// True when the backend is in buffer underrun (network gap). The Debug
  /// painter shows "BUFFERING" and bands decay instead of freezing.
  bool stale = false;

  /// Debug: for each band, how many ms ago its raw value last changed.
  /// -1 when no real data is available. Same length as [bars].
  List<double> bandAgeMs;

  /// Overall energy (0..1) — smoothed average of all bands.
  double energy = 0;

  /// Smoothed sub-band energies (0..1): bass (low ~16 bands),
  /// mid (~16), treble (high ~16) of the 48-band spectrum.
  double bass = 0;
  double mid = 0;
  double treble = 0;

  SpectrumFrame(this.bars, this.peaks)
      : bandAgeMs = List<double>.filled(bars.length, -1);

  void update(List<double> bars, List<double> peaks, double phase) {
    this.bars = bars;
    this.peaks = peaks;
    this.phase = phase;
    notifyListeners();
  }
}

/// Winamp-classic bar spectrum: gradient bars with falling peak caps.
class BarSpectrumPainter extends CustomPainter {
  BarSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final gap = size.width / n * 0.25;
    final barW = (size.width - gap * (n + 1)) / n;

    for (var i = 0; i < n; i++) {
      final x = gap + i * (barW + gap);
      final h = (bars[i] * 0.95 + 0.05) * size.height;
      final rect = Rect.fromLTWH(x, size.height - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()
          ..shader = _barGradient(rect)
          ..color = const Color(0xFFFFFFFF).withValues(alpha: dim),
      );

      // Peak cap: a thin bright marker that falls slower than the bar.
      final peakY = size.height - (_frame.peaks[i] * 0.95 + 0.05) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x, peakY - 2, barW, 2),
        Paint()..color = AppColors.onBackground.withValues(alpha: 0.9 * dim),
      );
    }
  }

  Shader _barGradient(Rect bounds) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [AppColors.primary, AppColors.accent],
      ).createShader(bounds);

  @override
  bool shouldRepaint(BarSpectrumPainter oldDelegate) => false;
}

/// LED block spectrum (winamp "blocks"): each bar is a column of discrete
/// chunks, lit up to the current height, with a lit peak block.
class BlockSpectrumPainter extends CustomPainter {
  BlockSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    const rows = 18;
    final gap = size.width / n * 0.3;
    final blockW = (size.width - gap * (n + 1)) / n;
    final cellH = size.height / rows;
    final blockH = cellH * 0.72;

    for (var i = 0; i < n; i++) {
      final x = gap + i * (blockW + gap);
      final lit = (bars[i] * 0.95 + 0.05) * rows;
      final peakRow = (_frame.peaks[i] * 0.95 + 0.05) * rows;
      for (var r = 0; r < rows; r++) {
        final y = size.height - (r + 1) * cellH + (cellH - blockH) / 2;
        if (lit - r > 0.02) {
          final t = (r / rows).clamp(0.0, 1.0);
          final color = Color.lerp(AppColors.primary, AppColors.accent, t)!;
          canvas.drawRect(
            Rect.fromLTWH(x, y, blockW, blockH),
            Paint()..color = color.withValues(alpha: dim),
          );
        } else {
          // Unlit block ghost so the matrix is always visible.
          canvas.drawRect(
            Rect.fromLTWH(x, y, blockW, blockH),
            Paint()..color = AppColors.onBackground.withValues(alpha: 0.05 * dim),
          );
        }
        // Lit peak block: bright marker one row above the current height.
        if ((peakRow - r).abs() < 0.6 && peakRow > lit - r) {
          canvas.drawRect(
            Rect.fromLTWH(x, y, blockW, blockH),
            Paint()..color = AppColors.onBackground.withValues(alpha: 0.9 * dim),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(BlockSpectrumPainter oldDelegate) => false;
}

/// Smooth filled line spectrum: a curve through the band tops with a soft
/// gradient fill and a bright stroke on the crest.
class LineSpectrumPainter extends CustomPainter {
  LineSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final step = size.width / (n - 1);

    Offset point(int i) =>
        Offset(i * step, size.height - (bars[i] * 0.9 + 0.05) * size.height);

    final path = Path()..moveTo(0, size.height);
    if (n >= 4) {
      final p1 = point(1);
      path.lineTo(point(0).dx, point(0).dy);
      path.lineTo((point(0).dx + p1.dx) / 2, (point(0).dy + p1.dy) / 2);
      for (var i = 1; i < n - 1; i++) {
        final a = point(i), b = point(i + 1);
        path.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      }
      final last = point(n - 1);
      path.lineTo(last.dx, last.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.25 * dim),
            AppColors.accent.withValues(alpha: 0.55 * dim),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withValues(alpha: dim),
    );
  }

  @override
  bool shouldRepaint(LineSpectrumPainter oldDelegate) => false;
}

/// Mirrored spectrum: bars grow up AND down from the vertical center line.
class MirrorSpectrumPainter extends CustomPainter {
  MirrorSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final gap = size.width / n * 0.3;
    final barW = (size.width - gap * (n + 1)) / n;
    final half = size.height / 2;
    final gradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [AppColors.primary, AppColors.accent],
    );

    for (var i = 0; i < n; i++) {
      final x = gap + i * (barW + gap);
      final h = (bars[i] * 0.95 + 0.03) * half;
      for (final rect in [
        Rect.fromLTRB(x, half - h, x + barW, half),
        Rect.fromLTRB(x, half, x + barW, half + h),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()
            ..shader = gradient.createShader(rect)
            ..color = const Color(0xFFFFFFFF).withValues(alpha: dim),
        );
      }
      // Peak markers on both halves.
      final peakH = (_frame.peaks[i] * 0.95 + 0.03) * half;
      for (final y in [half - peakH - 2, half + peakH]) {
        canvas.drawRect(
          Rect.fromLTWH(x, y, barW, 2),
          Paint()..color = AppColors.onBackground.withValues(alpha: 0.8 * dim),
        );
      }
    }
    // Faint center line to anchor the mirror.
    canvas.drawRect(
      Rect.fromLTWH(0, half - 0.5, size.width, 1),
      Paint()..color = AppColors.onBackground.withValues(alpha: 0.12 * dim),
    );
  }

  @override
  bool shouldRepaint(MirrorSpectrumPainter oldDelegate) => false;
}

/// Layered wave spectrum (audio_visualizer "MultiWave"): several translucent
/// waves whose amplitudes are driven by bass / mid / treble energies, plus
/// the fine structure of the spectrum on the leading wave.
class WaveSpectrumPainter extends CustomPainter {
  WaveSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final mid = size.height / 2;
    final phase = _frame.phase;

    double bandEnergy(int from, int to) {
      var sum = 0.0;
      final end = to.clamp(0, n);
      for (var i = from; i < end; i++) {
        sum += bars[i];
      }
      return to > from ? sum / (to - from) : 0;
    }

    final bass = bandEnergy(0, n ~/ 3);
    final midE = bandEnergy(n ~/ 3, (2 * n) ~/ 3);
    final treble = bandEnergy((2 * n) ~/ 3, n);
    final waves = [
      (bass * 0.55 + 0.03, 1.6, AppColors.primary, 0.34),
      (midE * 0.45 + 0.025, 2.7, AppColors.purple, 0.30),
      (treble * 0.4 + 0.02, 4.2, AppColors.accent, 0.26),
    ];

    for (final (amp, freq, color, alpha) in waves) {
      final path = Path()..moveTo(0, mid);
      // Sample the spectrum across the wave so it carries band detail.
      for (var x = 0.0; x <= size.width; x += 4) {
        final t = x / size.width;
        final band = bars[(t * (n - 1)).floor()];
        final y = mid +
            math.sin(phase * freq + t * freq * 6.28) *
                amp *
                size.height *
                0.45 *
                (0.35 + band * 0.65);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, mid);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: alpha * dim),
      );
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: alpha * 0.18 * dim),
      );
    }
  }

  @override
  bool shouldRepaint(WaveSpectrumPainter oldDelegate) => false;
}

/// Radial spectrum (audio_visualizer "Circle"): bars radiate from a central
/// ring; the whole ring breathes with overall energy. Static orientation
/// (no rotation) — bars + giro didn't look good together.
class CircleSpectrumPainter extends CustomPainter {
  CircleSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height) * 0.22; // breathing ring
    var energy = 0.0;
    for (final b in bars) {
      energy += b;
    }
    energy /= n;
    final ringR = base * (1 + energy * 0.35);
    final maxLen = (math.min(size.width, size.height) / 2 - ringR) * 0.95;

    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi;
      final len = (bars[i] * 0.95 + 0.03) * maxLen;
      final inner =
          Offset(center.dx + math.cos(angle) * ringR, center.dy + math.sin(angle) * ringR);
      final outer = Offset(center.dx + math.cos(angle) * (ringR + len),
          center.dy + math.sin(angle) * (ringR + len));
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = math.max(2, math.min(size.width, size.height) * 0.012)
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(AppColors.primary, AppColors.accent, bars[i].clamp(0.0, 1.0))!
              .withValues(alpha: dim),
      );
      // Peak dot at the end of each ray.
      final peakLen = (_frame.peaks[i] * 0.95 + 0.03) * maxLen;
      final peak = Offset(center.dx + math.cos(angle) * (ringR + peakLen),
          center.dy + math.sin(angle) * (ringR + peakLen));
      canvas.drawCircle(
          peak, 1.6, Paint()..color = AppColors.onBackground.withValues(alpha: 0.8 * dim));
    }

    // Core ring.
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primary.withValues(alpha: 0.6 * dim),
    );
  }

  @override
  bool shouldRepaint(CircleSpectrumPainter oldDelegate) => false;
}

/// Retro dual VU meters with ballistic needles: bass/mid on the left, treble
/// on the right. The ticker already smooths the energies, and the needle
/// mapping makes motion feel continuous by design.
class VuSpectrumPainter extends CustomPainter {
  VuSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final w = size.width * 0.44;
    final h = size.height * 0.8;
    final top = size.height * 0.1;

    _drawMeter(canvas, Rect.fromLTWH(size.width * 0.02, top, w, h),
        _frame.bass, 'GRAVES');
    _drawMeter(canvas,
        Rect.fromLTWH(size.width * 0.98 - w, top, w, h), _frame.treble,
        'AGUDOS');

    // Center energy readout.
    final tp = TextPainter(
      text: TextSpan(
          text: '${(_frame.energy * 100).round()}%',
          style: TextStyle(
              color: AppColors.onBackground.withValues(alpha: 0.8 * dim),
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.45));
  }

  void _drawMeter(Canvas canvas, Rect r, double v, String label) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, const Radius.circular(8)),
      Paint()..color = AppColors.surfaceVariant.withValues(alpha: 0.5 * dim),
    );

    final cx = r.center.dx;
    final cy = r.bottom - 10;
    final len = r.height * 0.68;
    const maxDefl = math.pi * 0.7; // 126° sweep
    final angle = -maxDefl / 2 + v.clamp(0.0, 1.0) * maxDefl;

    // Scale arc ticks.
    for (var t = 0; t <= 10; t++) {
      final a = (-maxDefl / 2 + (t / 10) * maxDefl) - math.pi / 2;
      final c = math.cos(a), s = math.sin(a);
      final inner = Offset(cx + c * len * 0.86, cy + s * len * 0.86);
      final outer = Offset(cx + c * len * 0.98, cy + s * len * 0.98);
      canvas.drawLine(
          inner,
          outer,
          Paint()
            ..strokeWidth = 1.5
            ..color = (t >= 7 ? AppColors.warning : AppColors.muted)
                .withValues(alpha: 0.7 * dim));
    }

    // Needle (VU ballistics are handled upstream by the EMA smoothing).
    final tip = Offset(cx + math.sin(angle) * len, cy - math.cos(angle) * len);
    canvas.drawLine(
        Offset(cx, cy),
        tip,
        Paint()
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = AppColors.danger.withValues(alpha: 0.9 * dim));
    canvas.drawCircle(Offset(cx, cy), 4,
        Paint()..color = AppColors.onBackground.withValues(alpha: 0.9 * dim));

    final tp = TextPainter(
      text: TextSpan(
          text: label,
          style: TextStyle(
              color: AppColors.muted.withValues(alpha: 0.9 * dim),
              fontSize: 11,
              letterSpacing: 1.2)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r.center.dx - tp.width / 2, r.top + 6));
  }

  @override
  bool shouldRepaint(VuSpectrumPainter oldDelegate) => false;
}

/// Waterfall spectrogram: scrolling heatmap of raw backend frames. A new
/// column is appended on the right each frame; the whole field scrolls left.
class WaterfallSpectrumPainter extends CustomPainter {
  WaterfallSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  /// Ring buffer of recent raw frames (each 48 values).
  final List<Float32List> _history = <Float32List>[];
  static const _maxHistory = 160;

  @override
  void paint(Canvas canvas, Size size) {
    final raw = _frame.raw;
    if (raw != null && raw.isNotEmpty) {
      final copy = Float32List(raw.length);
      for (var i = 0; i < raw.length; i++) {
        copy[i] = raw[i];
      }
      _history.add(copy);
      if (_history.length > _maxHistory) _history.removeAt(0);
    }

    if (_history.isEmpty || size.width <= 0 || size.height <= 0) return;

    final n = _history.first.length;
    final colW = size.width / _maxHistory;
    final rowH = size.height / n;

    for (var c = 0; c < _history.length; c++) {
      final frame = _history[c];
      final x = size.width - (_history.length - c) * colW;
      for (var b = 0; b < n; b++) {
        final v = frame[b].clamp(0.0, 1.0);
        if (v < 0.02) continue;
        final hot = (v * v * 1.8).clamp(0.0, 1.0);
        final color = hot > 0.5
            ? Color.lerp(AppColors.primary, AppColors.accent, (hot - 0.5) * 2)!
            : Color.lerp(
                AppColors.surface, AppColors.primary, hot * 2)!;
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - (b + 1) * rowH, colW + 1, rowH + 1),
          Paint()..color = color.withValues(alpha: dim),
        );
      }
    }
  }

  @override
  bool shouldRepaint(WaterfallSpectrumPainter oldDelegate) => false;
}

/// Reactive starfield tunnel: stars fly toward the viewer, speed scales with
/// energy, bass makes the tunnel pulse. Motion is guaranteed by design.
class StarfieldSpectrumPainter extends CustomPainter {
  StarfieldSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  /// Star positions [x, y, z] in abstract space; seeded once, recycled.
  final List<double> _stars = [];
  static const _starCount = 90;
  static final _rng = math.Random();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    if (_stars.length != _starCount * 3) {
      _stars.clear();
      for (var i = 0; i < _starCount * 3; i++) {
        _stars.add(_rng.nextDouble());
      }
    }

    final energy = _frame.energy;
    final speed = 0.004 + energy * 0.022;
    final pulse = 1 + _frame.bass * 0.3;
    final halfW = size.width / 2;
    final halfH = size.height / 2;

    for (var i = 0; i < _starCount; i++) {
      final base = i * 3;
      var z = _stars[base + 2];
      z -= speed;
      if (z <= 0.04) {
        z = 1.0;
        _stars[base] = _rng.nextDouble();
        _stars[base + 1] = _rng.nextDouble();
      }
      _stars[base + 2] = z;
      final x = (_stars[base] * 2 - 1);
      final y = (_stars[base + 1] * 2 - 1);
      final scale = 1 / z;
      final px = halfW + x * scale * halfW * 0.3 * pulse;
      final py = halfH + y * scale * halfH * 0.3 * pulse;
      if (px < -30 || px > size.width + 30 || py < -30 || py > size.height + 30) {
        continue;
      }
      final r = (2.2 / z).clamp(0.6, 5.0);
      final c = Color.lerp(AppColors.muted, AppColors.primary, 1 - z)!;
      canvas.drawCircle(
        Offset(px, py),
        r,
        Paint()..color = c.withValues(alpha: (1 - z) * 0.95 * dim),
      );
    }
  }

  @override
  bool shouldRepaint(StarfieldSpectrumPainter oldDelegate) => false;
}

/// Liquid metaball bubbles: organic blobs that grow with bass/mid/treble
/// energies, drifting on a slow noise-like motion. Always alive.
class BubblesSpectrumPainter extends CustomPainter {
  BubblesSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = _frame.phase;
    final energies = [_frame.bass, _frame.mid, _frame.treble];
    final colors = [AppColors.primary, AppColors.purple, AppColors.accent];

    // 3 master blobs (one per band group) + orbiting satellites.
    for (var g = 0; g < 3; g++) {
      final e = energies[g].clamp(0.0, 1.0);
      final cx = size.width * (0.3 + 0.2 * g + math.sin(t * 0.5 + g * 2) * 0.08);
      final cy = size.height * (0.5 + math.cos(t * 0.4 + g * 1.7) * 0.18);
      final r = (0.10 + e * 0.16) * math.min(size.width, size.height);

      // Soft body: layered translucent circles (cheap metaball feel).
      for (var layer = 3; layer >= 1; layer--) {
        canvas.drawCircle(
          Offset(cx, cy),
          r * (layer / 3) * 1.25,
          Paint()
            ..color = colors[g].withValues(
                alpha: 0.10 * dim / layer),
        );
      }
      // Bright core.
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.45,
        Paint()
          ..shader = RadialGradient(colors: [
            colors[g].withValues(alpha: 0.9 * dim),
            colors[g].withValues(alpha: 0.0)
          ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );

      // Small satellites orbiting, sized by their band value.
      for (var s = 0; s < 5; s++) {
        final ang = t * (0.3 + 0.1 * g) + s * (2 * math.pi / 5);
        final dist = r * (1.6 + 0.2 * math.sin(t + s));
        final sx = cx + math.cos(ang) * dist;
        final sy = cy + math.sin(ang) * dist * 0.7;
        final sr = (2 + e * 5) * (1 + 0.3 * math.sin(t * 2 + s));
        canvas.drawCircle(
          Offset(sx, sy),
          sr,
          Paint()..color = colors[g].withValues(alpha: 0.5 * dim),
        );
      }
    }
  }

  @override
  bool shouldRepaint(BubblesSpectrumPainter oldDelegate) => false;
}

/// Ambient bass-pulse glow: a soft breathing radial light behind everything,
/// intensity driven by overall energy. Suggests "the room breathes".
class PulseSpectrumPainter extends CustomPainter {
  PulseSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final e = _frame.energy;
    // Heartbeat-style double-thump derived from the phase clock.
    final beat = math.pow(math.max(0, math.sin(_frame.phase * 2)), 3).toDouble();
    final intensity = (e * 0.6 + beat * 0.4).clamp(0.0, 1.0);

    // Concentric expanding rings.
    for (var ring = 0; ring < 3; ring++) {
      final rr = (0.18 + ring * 0.16) * size.width +
          beat * size.width * 0.06;
      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + e * 2
          ..color = Color.lerp(AppColors.primary, AppColors.accent, e)!
              .withValues(alpha: (0.35 - ring * 0.1) * dim * intensity),
      );
    }

    // Central glow.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(AppColors.primary, AppColors.accent, e)!
              .withValues(alpha: 0.22 * dim * intensity),
          AppColors.background.withValues(alpha: 0),
        ]).createShader(Rect.fromCircle(
            center: Offset(size.width / 2, size.height / 2),
            radius: size.shortestSide * 0.7)),
    );
  }

  @override
  bool shouldRepaint(PulseSpectrumPainter oldDelegate) => false;
}

/// Sonos/Alexa-style level ring: a circular ring around a central energy
/// readout that undulates with per-band amplitude, rotating slowly.
class RingSpectrumPainter extends CustomPainter {
  RingSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) * 0.3;
    final rot = _frame.phase * 0.2;

    // Wavy closed ring: each bar pushes the ring radius outward.
    final path = Path()..moveTo(
      center.dx + math.cos(rot) * (baseR + bars[0] * baseR * 0.5),
      center.dy + math.sin(rot) * (baseR + bars[0] * baseR * 0.5),
    );
    for (var i = 1; i <= n; i++) {
      final b = bars[i % n];
      final a = rot + (i / n) * 2 * math.pi;
      path.lineTo(center.dx + math.cos(a) * (baseR + b * baseR * 0.5),
          center.dy + math.sin(a) * (baseR + b * baseR * 0.5));
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.primary.withValues(alpha: 0.85 * dim),
    );
    // Inner soft fill.
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.10 * dim),
    );

    // Second ring — inverted phase for depth.
    final path2 = Path()..moveTo(
      center.dx + math.cos(-rot) * (baseR * 0.62 + (1 - bars[0]) * baseR * 0.12),
      center.dy + math.sin(-rot) * (baseR * 0.62 + (1 - bars[0]) * baseR * 0.12),
    );
    for (var i = 1; i <= n; i++) {
      final b = bars[(n - i) % n];
      final a = -rot + (i / n) * 2 * math.pi;
      path2.lineTo(
          center.dx + math.cos(a) * (baseR * 0.62 + (1 - b) * baseR * 0.12),
          center.dy + math.sin(a) * (baseR * 0.62 + (1 - b) * baseR * 0.12));
    }
    path2.close();
    canvas.drawPath(
      path2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.accent.withValues(alpha: 0.4 * dim),
    );

    // Center energy number.
    final tp = TextPainter(
      text: TextSpan(
          text: '${(_frame.energy * 100).round()}',
          style: TextStyle(
              color: AppColors.onBackground.withValues(alpha: 0.9 * dim),
              fontSize: math.max(14, baseR * 0.28),
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(RingSpectrumPainter oldDelegate) => false;
}

/// Reactive color-field: hue shifts continuously with energy, painting a
/// flowing aurora gradient across the whole area.
class ReactiveSpectrumPainter extends CustomPainter {
  ReactiveSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final t = _frame.phase;
    final e = _frame.energy;
    // Hue rotation driven by energy.
    final hue = (t * 12 + e * 60) % 360.0;

    final base = HSLColor.fromAHSL(1, hue, 0.7, 0.5).toColor();
    final base2 = HSLColor.fromAHSL(1, (hue + 80) % 360, 0.65, 0.55).toColor();
    final base3 = HSLColor.fromAHSL(1, (hue + 200) % 360, 0.6, 0.6).toColor();

    // Aurora bands flowing horizontally, amplitude scales with energy.
    for (var band = 0; band < 4; band++) {
      final amplitude = 0.16 + band * 0.02 + e * 0.2;
      final offset = math.sin(t * 0.6 + band * 1.4) * 0.3;
      final path = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 8) {
        final u = x / size.width;
        final y = size.height * (0.3 + band * 0.12 + offset * 0.4) +
            math.sin(u * 6 * math.pi + t * (1 + band * 0.3) + band * 2) *
                size.height *
                amplitude *
                0.4;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      final alpha = (0.20 - band * 0.03) * dim;
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              base.withValues(alpha: alpha),
              base2.withValues(alpha: alpha),
              base3.withValues(alpha: alpha),
            ],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(ReactiveSpectrumPainter oldDelegate) => false;
}

/// Kaleidoscope: the spectrum bars mirrored 6× around the center with slow
/// rotation — same data, extra rotational motion. Cheap and hypnotic.
class KaleidoscopeSpectrumPainter extends CustomPainter {
  KaleidoscopeSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final bars = _frame.bars;
    final n = bars.length;
    if (n == 0 || size.width <= 0 || size.height <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.48;
    final rot = _frame.phase * 0.25;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    for (var seg = 0; seg < 6; seg++) {
      canvas.save();
      canvas.rotate(rot + seg * math.pi / 3);
      // Draw half a spectrum wedge (only 24 bars needed; fold the rest).
      for (var i = 0; i < n ~/ 2; i++) {
        final v = bars[i].clamp(0.0, 1.0);
        final startA = (i / (n ~/ 2)) * (math.pi / 6);
        final len = maxR * (0.15 + v * 0.85);
        final rect = Rect.fromLTWH(maxR * 0.12, -startA * len, len, math.max(2, maxR * 0.012));
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = Color.lerp(AppColors.primary, AppColors.accent, v)!
              .withValues(alpha: 0.75 * dim),
        );
      }
      // Mirror the wedge for the kaleidoscope fold.
      canvas.save();
      canvas.scale(1, -1);
      for (var i = 0; i < n ~/ 2; i++) {
        final v = bars[i].clamp(0.0, 1.0);
        final startA = (i / (n ~/ 2)) * (math.pi / 6);
        final len = maxR * (0.15 + v * 0.85);
        final rect = Rect.fromLTWH(maxR * 0.12, -startA * len, len, math.max(2, maxR * 0.012));
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = Color.lerp(AppColors.primary, AppColors.accent, v)!
              .withValues(alpha: 0.4 * dim),
        );
      }
      canvas.restore();
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(KaleidoscopeSpectrumPainter oldDelegate) => false;
}

/// Debug view: raw backend band values as live-updating numbers in a
/// horizontal strip, plus a measured updates-per-second counter. Ground
/// truth to check whether data really changes many times per second.
class DebugSpectrumPainter extends CustomPainter {
  DebugSpectrumPainter({required SpectrumFrame frame, this.dim = 1.0})
      : _frame = frame,
        super(repaint: frame);

  final SpectrumFrame _frame;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final raw = _frame.raw;
    final real = _frame.realUps;
    final content = _frame.contentUps;
    final stale = _frame.stale;
    final live = real >= 5 && !stale; // healthy stream of fresh, non-stale messages
    final fresh = content >= 5; // values actually changing fast enough
    final isFake = raw == null; // pseudo mode — no backend data

    // Status priority: BUFFERING > LIVE > PSEUDO > CONGELADO > ATASCADO
    final String label;
    final Color labelColor;
    if (stale && !isFake) {
      label = 'BUFFERING';
      labelColor = AppColors.warning;
    } else if (live && fresh) {
      label = 'LIVE';
      labelColor = AppColors.accent;
    } else if (isFake) {
      label = 'PSEUDO';
      labelColor = AppColors.warning;
    } else if (live && !fresh) {
      label = 'CONGELADO';
      labelColor = AppColors.purple;
    } else {
      label = 'ATASCADO';
      labelColor = AppColors.danger;
    }

    // --- Status banner -------------------------------------------------
    final status = TextPainter(
      text: TextSpan(children: [
        TextSpan(
          text: label,
          style: TextStyle(
            color: labelColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        TextSpan(
          text: '  msg ${real.toStringAsFixed(0)}/s · datos ${content.toStringAsFixed(0)}/s',
          style: TextStyle(
            color: AppColors.onBackground.withValues(alpha: 0.7 * dim),
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
      textDirection: TextDirection.ltr,
    )..layout();
    status.paint(canvas, const Offset(8, 6));

    final source = raw ?? _frame.bars;
    final ages = _frame.bandAgeMs;
    final n = source.length;
    if (n == 0) return;
    final cellW = size.width / n;

    for (var i = 0; i < n; i++) {
      final v = source[i];
      final x = i * cellW;
      final age = ages.length > i ? ages[i] : -1;

      // Micro bar, colored by freshness: green fresh → amber → red stale.
      final barH = v * size.height * 0.42;
      final ageColor = age < 0
          ? AppColors.muted
          : age < 150
              ? AppColors.accent
              : age < 500
                  ? AppColors.warning
                  : AppColors.danger;
      canvas.drawRect(
        Rect.fromLTWH(x + cellW * 0.2, size.height - barH, cellW * 0.6, barH),
        Paint()..color = ageColor.withValues(alpha: 0.4 * dim),
      );

      // The live number (skip if too narrow for legibility).
      final tp = TextPainter(
        text: TextSpan(
            text: v.toStringAsFixed(2),
            style: TextStyle(
              color: isFake
                  ? AppColors.muted
                  : Color.lerp(AppColors.onBackground, AppColors.accent,
                      v.clamp(0.0, 1.0))!
                      .withValues(alpha: dim),
              fontSize: 10,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        textDirection: TextDirection.ltr,
      )..layout();
      if (tp.width <= cellW) {
        tp.paint(
            canvas, Offset(x + (cellW - tp.width) / 2, size.height * 0.34));
      }

      // Age badge under each bar: ms since this band's value last changed.
      final ap = TextPainter(
        text: TextSpan(
            text: age < 0 ? '--' : '${age.round()}',
            style: TextStyle(
              color: ageColor.withValues(alpha: 0.9 * dim),
              fontSize: 9,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        textDirection: TextDirection.ltr,
      )..layout();
      if (ap.width <= cellW) {
        ap.paint(canvas,
            Offset(x + (cellW - ap.width) / 2, size.height * 0.55));
      }
    }
  }

  @override
  bool shouldRepaint(DebugSpectrumPainter oldDelegate) => false;
}

/// Builds the painter matching [style]. All painters repaint from [frame],
/// so switching styles only rebuilds the CustomPaint child once.
CustomPainter buildPainter(VisualizerStyle style, SpectrumFrame frame, double dim) {
  switch (style) {
    case VisualizerStyle.bars:
      return BarSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.blocks:
      return BlockSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.line:
      return LineSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.mirror:
      return MirrorSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.wave:
      return WaveSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.circle:
      return CircleSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.vu:
      return VuSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.waterfall:
      return WaterfallSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.starfield:
      return StarfieldSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.bubbles:
      return BubblesSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.pulse:
      return PulseSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.ring:
      return RingSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.reactive:
      return ReactiveSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.kaleidoscope:
      return KaleidoscopeSpectrumPainter(frame: frame, dim: dim);
    case VisualizerStyle.debug:
      return DebugSpectrumPainter(frame: frame, dim: dim);
  }
}

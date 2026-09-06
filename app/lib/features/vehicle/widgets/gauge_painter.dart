import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

/// A needle gauge painted on canvas (speedometer / tachometer): colored arc
/// with major ticks and numbers, a smooth needle, and the big value in the
/// center. The needle animates because the whole widget rebuilds on every
/// poll (3 s) and lerps via [AnimatedGauge] in the screen.
class GaugePainter extends CustomPainter {
  GaugePainter({
    required this.value,
    required this.max,
    required this.unit,
    required this.redlineFrom,
    this.majorDivisions = 8,
    this.accent = AppColors.primary,
  });

  final double value;
  final double max;
  final String unit;
  /// The value from which the arc turns red (RPM redline). null = no redline.
  final double? redlineFrom;
  final int majorDivisions;
  final Color accent;

  static const _startAngle = 135.0; // degrees
  static const _sweepAngle = 270.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    // Background track.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = AppColors.surfaceVariant;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _rad(_startAngle), _rad(_sweepAngle), false, track);

    // Value fraction of the sweep.
    final fraction = (value / max).clamp(0.0, 1.0);

    // Redline arc (only for gauges that define one).
    if (redlineFrom != null) {
      final redFrom = (redlineFrom! / max).clamp(0.0, 1.0);
      final red = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = AppColors.danger.withValues(alpha: 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _rad(_startAngle + _sweepAngle * redFrom),
        _rad(_sweepAngle * (1 - redFrom)),
        false,
        red,
      );
    }

    // Active arc up to the current value.
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = _valueColor(fraction);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), _rad(_startAngle),
        _rad(_sweepAngle * fraction), false, active);

    // Ticks + numbers.
    for (var i = 0; i <= majorDivisions; i++) {
      final f = i / majorDivisions;
      final angle = _rad(_startAngle + _sweepAngle * f);
      final tickOut = Offset(math.cos(angle), math.sin(angle)) * (radius - 10);
      final tickIn = Offset(math.cos(angle), math.sin(angle)) * (radius - 20);
      final tick = Paint()
        ..strokeWidth = 2
        ..color = AppColors.muted.withValues(alpha: 0.9);
      canvas.drawLine(center + tickOut, center + tickIn, tick);

      final label = (max * f).round();
      final textTp = TextPainter(
        text: TextSpan(
          text: label % 1 == 0 ? '$label' : '',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = center + Offset(math.cos(angle), math.sin(angle)) * (radius - 34);
      textTp.paint(canvas, labelPos - Offset(textTp.width / 2, textTp.height / 2));
    }

    // Needle.
    final needleAngle = _rad(_startAngle + _sweepAngle * fraction);
    final needlePaint = Paint()
      ..color = _valueColor(fraction)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(math.cos(needleAngle), math.sin(needleAngle)) * (radius - 26), needlePaint);

    // Hub.
    canvas.drawCircle(center, 5, Paint()..color = AppColors.onBackground);
  }

  Color _valueColor(double fraction) {
    if (redlineFrom != null && value >= redlineFrom!) return AppColors.danger;
    if (fraction > 0.85) return AppColors.warning;
    return accent;
  }

  double _rad(double deg) => deg * math.pi / 180;

  @override
  bool shouldRepaint(GaugePainter old) =>
      old.value != value || old.max != max || old.redlineFrom != redlineFrom;
}
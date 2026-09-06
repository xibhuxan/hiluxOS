import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/animated_counter.dart';
import 'gauge_painter.dart';

/// A gauge that lerps its needle between polls (the backend pushes every 3 s;
/// the tween makes the motion fluid instead of jumpy).
class AnimatedGauge extends StatefulWidget {
  const AnimatedGauge({
    super.key,
    required this.value,
    required this.max,
    required this.unit,
    this.redlineFrom,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final double max;
  final String unit;
  final double? redlineFrom;
  final Duration duration;

  @override
  State<AnimatedGauge> createState() => _AnimatedGaugeState();
}

class _AnimatedGaugeState extends State<AnimatedGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _old = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0, end: widget.value)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _old = widget.value;
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant AnimatedGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = Tween<double>(begin: _old, end: widget.value)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _old = widget.value;
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => CustomPaint(
        painter: GaugePainter(
          value: _animation.value,
          max: widget.max,
          unit: widget.unit,
          redlineFrom: widget.redlineFrom,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCounter(
                value: _animation.value,
                builder: (v) => '${v.round()}',
              ),
              Text(
                widget.unit,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
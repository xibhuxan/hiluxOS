import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A rounded, animated progress bar with an optional color-by-threshold helper.
class AnimatedProgressBar extends StatefulWidget {
  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.radius = 8,
    this.color,
    this.backgroundColor,
    this.duration = const Duration(milliseconds: 600),
  });

  /// 0..1
  final double value;
  final double height;
  final double radius;
  final Color? color;
  final Color? backgroundColor;
  final Duration duration;

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _old = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = _build(widget.value);
    _old = widget.value;
    _controller.value = 1.0;
  }

  Animation<double> _build(double target) =>
      Tween<double>(begin: _old, end: target.clamp(0.0, 1.0))
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = _build(widget.value);
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
    final color = widget.color ?? AppColors.usageColor(widget.value);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Container(
        height: widget.height,
        color: widget.backgroundColor ?? AppColors.surfaceVariant,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _animation.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.75)],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

/// Counts from the previous value to [value] whenever it changes, displaying the
/// formatted result. Good for live metrics (temperature, RAM %, uptime).
class AnimatedCounter extends StatefulWidget {
  const AnimatedCounter({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  final num value;
  final Duration duration;
  final Curve curve;
  final String Function(num value) builder;

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<num> _animation;
  num _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = _buildAnimation(widget.value);
    _oldValue = widget.value;
    // Skip animation on the very first frame.
    _controller.value = 1.0;
  }

  Animation<num> _buildAnimation(num target) {
    return Tween<num>(begin: _oldValue, end: target)
        .animate(CurvedAnimation(parent: _controller, curve: widget.curve));
  }

  @override
  void didUpdateWidget(covariant AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animation = _buildAnimation(widget.value);
      _oldValue = widget.value;
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
      builder: (context, _) => Text(widget.builder(_animation.value)),
    );
  }
}
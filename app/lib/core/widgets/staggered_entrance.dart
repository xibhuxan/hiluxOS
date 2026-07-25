import 'package:flutter/material.dart';

/// Fades + slides up its child on first build. Use [index] to stagger a list
/// or grid: each item begins a bit later than the previous.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.itemDelay = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 420),
    this.offset = const Offset(0, 24),
  });

  final Widget child;
  final int index;
  final Duration itemDelay;
  final Duration duration;
  final Offset offset;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.offset.dy / 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final begin = Duration(milliseconds: widget.index * widget.itemDelay.inMilliseconds);
    Future.delayed(begin, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
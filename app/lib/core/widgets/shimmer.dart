import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A lightweight skeleton-shimmer placeholder: a rounded box whose surface
/// carries a soft highlight sweep while [loading] is true. Pure Flutter —
/// an animated [LinearGradient] repaints a single DecoratedBox, no package.
///
/// When [loading] is false it renders [child] untouched, so call sites can
/// write `Shimmer.box(loading: state.loading, child: content)` without
/// conditional branches.
class Shimmer extends StatefulWidget {
  const Shimmer({
    super.key,
    required this.loading,
    required this.child,
    this.width,
    this.height,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1300),
  });

  /// Skeleton dimensions. Ignored when not loading (child sizes itself).
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  final bool loading;
  final Widget child;
  final Duration duration;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Eager init (not a lazy `late final` initializer): dispose() must be
    // able to access `_controller` even when `loading` was false from the
    // first build and the field was never read.
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading) return widget.child;
    final radius = widget.borderRadius ?? BorderRadius.circular(8);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t - 0.6, 0),
              end: Alignment(-1 + 2 * t + 0.6, 0),
              colors: [
                AppColors.surfaceVariant,
                AppColors.surfaceTint,
                AppColors.surfaceVariant,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}

/// Ready-made shimmer rows for list placeholders — a leading square plus one
/// or two text lines, mirroring the shape of a real `ListTile`.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Shimmer(loading: true, width: 40, height: 40, borderRadius: BorderRadius.circular(6), child: const SizedBox()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Shimmer(loading: true, height: 14, borderRadius: BorderRadius.circular(4), child: const SizedBox()),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: Shimmer(loading: true, height: 10, borderRadius: BorderRadius.circular(4), child: const SizedBox()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

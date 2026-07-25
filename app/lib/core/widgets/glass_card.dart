import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A frosted-glass style card: semi-transparent surface, subtle border, rounded
/// corners and a soft shadow. Optional accent glow behind the card.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.accentGlow = false,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool accentGlow;
  final VoidCallback? onTap;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: accentGlow
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: AppColors.surface.withValues(alpha: 0.72),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: border != null
                ? BoxDecoration(border: border, borderRadius: BorderRadius.circular(radius))
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
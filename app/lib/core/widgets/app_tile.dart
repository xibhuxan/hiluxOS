import 'package:flutter/material.dart';
import '../theme/colors.dart';
import 'glass_card.dart';

/// A launcher tile for the app drawer: icon, name, optional live metric.
class AppTile extends StatelessWidget {
  const AppTile({
    super.key,
    required this.icon,
    required this.name,
    required this.color,
    this.metric,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String name;
  final Color color;
  final String? metric;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accentGlow: enabled,
      padding: const EdgeInsets.all(16),
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const Spacer(),
                Icon(enabled ? Icons.chevron_right : Icons.lock_outline,
                    color: AppColors.muted, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (metric != null)
              Text(metric!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (!enabled)
              const Text('Próximamente', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
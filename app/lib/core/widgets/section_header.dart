import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Consistent section header used across the System and Settings screens:
/// icon + title on the app's glass style, with a hairline divider below.
/// Keeps every card visually aligned without repeating the same rows.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (trailing != null) ...[
              const Spacer(),
              trailing!,
            ],
          ],
        ),
        const SizedBox(height: 4),
        Divider(color: AppColors.surfaceVariant, height: 1, thickness: 1),
      ],
    );
  }
}

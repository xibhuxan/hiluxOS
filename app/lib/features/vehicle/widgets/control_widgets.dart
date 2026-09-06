import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../vehicle_provider.dart';

/// Engine start/stop. Real-car look: a big round power button that turns
/// green while running (ignition on) and stays neutral while parked.
class EngineButton extends ConsumerWidget {
  const EngineButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(vehicleProvider).snapshot;
    final on = snap?.ignition ?? false;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => ref.read(vehicleProvider.notifier).setIgnition(!on),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? AppColors.accent.withValues(alpha: 0.18) : AppColors.surfaceVariant,
              border: Border.all(
                color: on ? AppColors.accent : AppColors.muted.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 22,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              Icons.power_settings_new,
              size: 32,
              color: on ? AppColors.accent : AppColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            on ? 'Motor encendido' : 'Motor apagado',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: on ? AppColors.accent : AppColors.muted,
            ),
          ),
          Text(
            on ? 'Pulsa para apagar' : 'Arranca para conducir',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// One toggle row inside a control card. House style: icon, label, optional
/// helper text, and the switch on the right (SwitchListTile look, hand-built
/// to fit the glass cards).
class ControlToggle extends StatelessWidget {
  const ControlToggle({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.helper,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? helper;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? (value ? AppColors.primary : AppColors.muted)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  if (helper != null)
                    Text(helper!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}
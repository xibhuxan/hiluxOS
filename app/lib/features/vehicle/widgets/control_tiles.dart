import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../vehicle_provider.dart';

/// Turn signals: left / hazard / right one-shot buttons with real-car mutual
/// exclusion (the mock driver resolves it; the UI sends one key at a time).
class TurnSignalButtons extends ConsumerWidget {
  const TurnSignalButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(vehicleProvider).snapshot;
    if (snap == null) return const SizedBox.shrink();
    final notifier = ref.read(vehicleProvider.notifier);

    Widget signal(String label, IconData icon, bool active, Color color, VoidCallback onTap) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.18) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 20, color: active ? color : AppColors.muted),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active ? color : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        signal('Izq.', Icons.arrow_back, snap.turnLeft, AppColors.primary,
            () => notifier.setSignals(left: !snap.turnLeft)),
        signal('Warning', Icons.warning_amber_rounded, snap.hazard, AppColors.danger,
            () => notifier.setSignals(hazard: !snap.hazard)),
        signal('Dcha.', Icons.arrow_forward, snap.turnRight, AppColors.primary,
            () => notifier.setSignals(right: !snap.turnRight)),
      ],
    );
  }
}

/// Central lock + anti-theft alarm, one pill each.
class LockAlarmRow extends ConsumerWidget {
  const LockAlarmRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snap = ref.watch(vehicleProvider).snapshot;
    final notifier = ref.read(vehicleProvider.notifier);
    if (snap == null) return const SizedBox.shrink();

    Widget pill(IconData icon, String label, bool active, Color color, VoidCallback onTap) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active ? color.withValues(alpha: 0.18) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? color : Colors.transparent, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: active ? color : AppColors.muted),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? color : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return Row(
      children: [
        pill(
          snap.locked ? Icons.lock : Icons.lock_open,
          snap.locked ? 'Cerrado' : 'Abierto',
          snap.locked,
          AppColors.accent,
          () => notifier.setLock(!snap.locked),
        ),
        pill(
          snap.alarmArmed ? Icons.security : Icons.security_outlined,
          snap.alarmArmed ? 'Alarma activa' : 'Alarma',
          snap.alarmArmed,
          AppColors.warning,
          () => notifier.setAlarm(!snap.alarmArmed),
        ),
      ],
    );
  }
}
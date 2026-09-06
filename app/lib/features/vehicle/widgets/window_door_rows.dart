import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/progress_bar.dart';
import '../vehicle_provider.dart';

/// One power window row: label, animated position bar, and up/stop/down
/// buttons (tap = start the travel, stop = freeze it; the mock ends the
/// travel analytically at 0/1).
class WindowRow extends ConsumerWidget {
  const WindowRow({super.key, required this.window});

  final VehicleWindowInfo window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vehicleProvider.notifier);
    final moving = window.moving;

    Widget arrow(IconData icon, String action, Color color) => InkWell(
          onTap: () => notifier.windowAction(window.id, action),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              window.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: AnimatedProgressBar(
              value: window.position,
              height: 8,
              color: moving == null ? AppColors.primary : AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          arrow(Icons.arrow_upward, 'up', AppColors.onBackground),
          const SizedBox(width: 4),
          arrow(Icons.stop, 'stop', moving != null ? AppColors.danger : AppColors.muted),
          const SizedBox(width: 4),
          arrow(Icons.arrow_downward, 'down', AppColors.onBackground),
        ],
      ),
    );
  }
}

/// One door row: label + open/close toggle (tap anywhere on the row).
class DoorRow extends ConsumerWidget {
  const DoorRow({super.key, required this.door});

  final VehicleDoorInfo door;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(vehicleProvider.notifier);

    return InkWell(
      onTap: () => notifier.setDoor(door.id, !door.open),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              door.open ? Icons.meeting_room : Icons.door_front_door,
              size: 20,
              color: door.open ? AppColors.warning : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(door.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Text(
              door.open ? 'Abierta' : 'Cerrada',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: door.open ? AppColors.warning : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
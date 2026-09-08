import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../vehicle_provider.dart';
import 'window_position_lerp.dart';

/// One power window row: label, live position bar, and up/stop/down buttons
/// (tap = start the travel, stop = freeze it; the mock ends the travel
/// analytically at 0/1).
///
/// The bar interpolates locally via [WindowPositionLerp] while `moving` is
/// set: the poll only samples the position every 3 s, so without this the
/// bar would jump tap → mid → end. Each poll re-syncs from the backend value
/// so no drift accumulates.
class WindowRow extends ConsumerStatefulWidget {
  const WindowRow({super.key, required this.window});

  final VehicleWindowInfo window;

  @override
  ConsumerState<WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends ConsumerState<WindowRow>
    with TickerProviderStateMixin {
  late final WindowPositionLerp _lerp;

  @override
  void initState() {
    super.initState();
    _lerp = WindowPositionLerp(
      vsync: this,
      onChanged: () => setState(() {}),
      position: widget.window.position,
      moving: widget.window.moving,
    );
  }

  @override
  void didUpdateWidget(covariant WindowRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lerp.sync(widget.window.position, widget.window.moving);
  }

  @override
  void dispose() {
    _lerp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(vehicleProvider.notifier);
    final moving = widget.window.moving;
    final position = _lerp.position;

    Widget arrow(IconData icon, String action, Color color) => InkWell(
          onTap: () => notifier.windowAction(widget.window.id, action),
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
              widget.window.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 8,
                color: AppColors.surfaceVariant,
                child: FractionallySizedBox(
                  key: Key('window-bar-${widget.window.id}'),
                  alignment: Alignment.centerLeft,
                  widthFactor: position,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          moving == null ? AppColors.primary : AppColors.warning,
                          (moving == null ? AppColors.primary : AppColors.warning)
                              .withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
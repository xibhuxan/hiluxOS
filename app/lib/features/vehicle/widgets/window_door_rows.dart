import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../vehicle_provider.dart';

/// Window travel speed, in position units per second. Matches the mock
/// driver's WINDOW_TRAVEL_PER_SECOND (0.5 — full travel = 2 s) so the
/// client-side interpolation tracks the backend exactly.
const double kWindowTravelPerSecond = 0.5;

/// One power window row: label, live position bar, and up/stop/down buttons
/// (tap = start the travel, stop = freeze it; the mock ends the travel
/// analytically at 0/1).
///
/// The bar interpolates locally while `moving != null`: the poll only
/// samples the position every 3 s, so without this the bar would jump from
/// tap → mid → end. A Ticker integrates `dt * 0.5` towards the destination
/// (1 for 'down', 0 for 'up'); each poll re-syncs from the backend value so
/// no drift accumulates.
class WindowRow extends ConsumerStatefulWidget {
  const WindowRow({super.key, required this.window});

  final VehicleWindowInfo window;

  @override
  ConsumerState<WindowRow> createState() => _WindowRowState();
}

class _WindowRowState extends ConsumerState<WindowRow>
    with TickerProviderStateMixin {
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;
  late double _position;

  @override
  void initState() {
    super.initState();
    _position = widget.window.position;
    if (widget.window.moving != null) _startTicker();
  }

  @override
  void didUpdateWidget(covariant WindowRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Poll arrived: re-sync from the backend position (no drift) and start /
    // stop the ticker according to the fresh `moving` flag.
    _position = widget.window.position;
    if (widget.window.moving != null) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    if (_ticker != null) return; // already running — keep the local position
    _lastTick = Duration.zero;
    _ticker = createTicker(_onTick)..start();
  }

  void _stopTicker() {
    _ticker?.dispose();
    _ticker = null;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final direction = widget.window.moving == 'down' ? 1.0 : -1.0;
    final next = (_position + direction * dt * kWindowTravelPerSecond).clamp(0.0, 1.0);
    if (next != _position) setState(() => _position = next);
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(vehicleProvider.notifier);
    final moving = widget.window.moving;

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
                  widthFactor: _position,
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
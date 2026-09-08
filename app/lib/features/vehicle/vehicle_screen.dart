import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../layout/app_shell.dart';
import 'vehicle_provider.dart';
import 'widgets/car_diagram.dart';
import 'widgets/control_panel.dart';
import 'widgets/dashboard.dart';

/// The vehicle app's three views.
enum VehicleTab { car, control, dashboard }

/// The vehicle app: one screen, three faces.
///
/// - **Coche** — a top-down interactive diagram of the Hilux (tap doors and
///   windows, lights and turn signals painted live).
/// - **Control** — act on the car (engine, lights, turn signals, lock, alarm,
///   doors, windows) in the house glass style.
/// - **Dashboard** — a pretty instrument cluster (speed + RPM gauges, fuel /
///   coolant / battery, cluster tell-tales), with a full-screen mode that
///   reuses the shell's FullscreenHost.
///
/// Same state all ways: everything is the single `vehicleProvider` poll.
class VehicleScreen extends ConsumerStatefulWidget {
  const VehicleScreen({super.key});

  @override
  ConsumerState<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends ConsumerState<VehicleScreen> {
  VehicleTab _tab = VehicleTab.car;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehicleProvider);
    final snap = state.snapshot;
    final connected = snap != null && snap.connected;

    if (snap == null) {
      // Backend unreachable or still loading the first poll.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car, size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
            const SizedBox(height: 10),
            Text(
              state.error != null ? 'Backend no disponible' : 'Conectando con el vehículo…',
              style: const TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Mode toggle: Coche ⇄ Control ⇄ Dashboard.
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ModeToggle(
            tab: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        Expanded(
          child: !connected
              ? _notConnected()
              : switch (_tab) {
                  VehicleTab.dashboard =>
                    Dashboard(snap: snap, onFullscreen: _enterFullscreen),
                  VehicleTab.control => const ControlPanel(),
                  VehicleTab.car => SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: AspectRatio(
                        aspectRatio: 0.52,
                        child: CarDiagram(snap: snap),
                      ),
                    ),
                },
        ),
      ],
    );
  }

  Widget _notConnected() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link_off, size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          const Text('No conectado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          const Text('Esperando a la centralita del vehículo',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }

  void _enterFullscreen() {
    final shell = context.findAncestorStateOfType<AppShellState>();
    shell?.enterFullscreen(
      (context, exit) {
        final snap = ref.watch(vehicleProvider).snapshot;
        if (snap == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Dashboard(snap: snap);
      },
      background: AppColors.background,
    );
  }
}

/// Segmented Coche/Control/Dashboard toggle in the house style.
class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.tab, required this.onChanged});

  final VehicleTab tab;
  final ValueChanged<VehicleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    // Each segment emits ITS OWN tab. (The previous bool version emitted
    // `!active`, which made the inactive segment re-emit the current mode.)
    Widget segment(String label, IconData icon, VehicleTab value) {
      final active = tab == value;
      return Expanded(
        child: InkWell(
          onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.primary.withValues(alpha: 0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          segment('Coche', Icons.directions_car_outlined, VehicleTab.car),
          const SizedBox(width: 3),
          segment('Control', Icons.tune, VehicleTab.control),
          const SizedBox(width: 3),
          segment('Dashboard', Icons.dashboard_outlined, VehicleTab.dashboard),
        ],
      ),
    );
  }
}
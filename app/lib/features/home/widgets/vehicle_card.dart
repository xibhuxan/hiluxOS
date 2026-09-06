import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../vehicle/vehicle_provider.dart';

/// Vehicle card. Backed by the backend Vehicle HAL (`GET /vehicle`).
/// When the driver reports `connected: false` (or the backend is unreachable)
/// the card degrades to the "No conectado" state.
class VehicleCard extends ConsumerWidget {
  const VehicleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vehicleProvider);
    final snap = state.snapshot;
    final connected = snap != null && snap.connected;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, color: AppColors.muted),
              const SizedBox(width: 8),
              const Text('Vehículo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  connected ? 'En marcha' : 'HAL',
                  style: TextStyle(
                      color: connected ? AppColors.accent : AppColors.muted,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (connected) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${snap.speedKmh ?? 0}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Text('km/h',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                Text('${snap.rpm ?? 0} rpm',
                    style: const TextStyle(fontSize: 14, color: AppColors.onBackground)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${snap.coolantTempC?.toStringAsFixed(0) ?? '—'} °C · '
              '${snap.batteryVoltage?.toStringAsFixed(1) ?? '—'} V · '
              '${((snap.fuelLevel ?? 0) * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (snap.lowBeams)
                  _chip(Icons.lightbulb, 'Cortas', AppColors.warning),
                if (snap.hazard)
                  _chip(Icons.warning_amber_rounded, 'Warning', AppColors.danger),
                _chip(
                  snap.locked ? Icons.lock : Icons.lock_open,
                  snap.locked ? 'Cerrado' : 'Abierto',
                  snap.locked ? AppColors.accent : AppColors.muted,
                ),
                _chip(Icons.meeting_room,
                    '${snap.doorsClosed}/${snap.doors.length} puertas', AppColors.muted),
                if (snap.windows.isNotEmpty)
                  _chip(Icons.window, '${snap.windowsClosed}/${snap.windows.length} ventanillas',
                      snap.windowsClosed == snap.windows.length ? AppColors.muted : AppColors.warning),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Icon(Icons.link_off, color: AppColors.muted.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                const Text('No conectado',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              state.error != null && snap == null
                  ? 'Backend no disponible'
                  : 'Esperando a la centralita del vehículo',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, color: AppColors.onBackground)),
          ],
        ),
      );
}
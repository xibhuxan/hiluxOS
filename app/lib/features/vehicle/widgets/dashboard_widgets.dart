import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/progress_bar.dart';
import '../vehicle_provider.dart';

/// One gauge label row (icon + label + live value).
class _GaugeMetric extends StatelessWidget {
  const _GaugeMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.muted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.onBackground,
            )),
      ],
    );
  }
}

/// Dashboard side column: fuel / coolant / battery levels with animated bars,
/// plus odometer. Degrades to muted dashes when the values are null.
class DashboardMetrics extends StatelessWidget {
  const DashboardMetrics({super.key, required this.snap});

  final VehicleSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final fuel = snap.fuelLevel;
    final coolant = snap.coolantTempC;
    final battery = snap.batteryVoltage;
    final odo = snap.odometerKm;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            _GaugeMetric(
              icon: Icons.local_gas_station,
              label: 'Combustible',
              value: fuel == null ? '—' : '${(fuel * 100).round()}%',
              color: (fuel ?? 1) < 0.15 ? AppColors.danger : null,
            ),
            const SizedBox(height: 4),
            AnimatedProgressBar(
              value: fuel ?? 0,
              color: (fuel ?? 1) < 0.15 ? AppColors.danger : AppColors.accent,
            ),
          ],
        ),
        Column(
          children: [
            _GaugeMetric(
              icon: Icons.device_thermostat,
              label: 'Refrigerante',
              value: coolant == null ? '—' : '${coolant.toStringAsFixed(0)} °C',
              color: AppColors.tempColor(coolant ?? 0),
            ),
            const SizedBox(height: 4),
            AnimatedProgressBar(
              value: ((coolant ?? 0) / 120).clamp(0.0, 1.0),
              color: AppColors.tempColor(coolant ?? 0),
            ),
          ],
        ),
        Column(
          children: [
            _GaugeMetric(
              icon: Icons.battery_charging_full,
              label: 'Batería',
              value: battery == null ? '—' : '${battery.toStringAsFixed(1)} V',
              color: battery != null && battery < 12.0 ? AppColors.danger : null,
            ),
            const SizedBox(height: 4),
            AnimatedProgressBar(
              value: ((battery ?? 0) - 11.5) / 3.0,
              color: (battery ?? 13) < 12.0 ? AppColors.danger : AppColors.accent,
            ),
          ],
        ),
        _GaugeMetric(
          icon: Icons.speed,
          label: 'Odómetro',
          value: odo == null ? '—' : '${odo.toStringAsFixed(0)} km',
        ),
      ],
    );
  }
}

/// Cluster tell-tales: turn signals blink, lights/lock/alarm/doors light up.
/// One row of classic cluster icons — the ones a real car shows.
class ClusterTelltaleRow extends StatefulWidget {
  const ClusterTelltaleRow({super.key, required this.snap});

  final VehicleSnapshot snap;

  @override
  State<ClusterTelltaleRow> createState() => _ClusterTelltaleRowState();
}

class _ClusterTelltaleRowState extends State<ClusterTelltaleRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snap;
    return AnimatedBuilder(
      animation: _blink,
      builder: (context, _) {
        final blinkOn = _blink.value > 0.5;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (snap.turnLeft)
              Icon(Icons.arrow_back_ios_new,
                  size: 22, color: blinkOn ? AppColors.warning : AppColors.warning.withValues(alpha: 0.25)),
            const SizedBox(width: 12),
            if (snap.hazard)
              Icon(Icons.warning_amber_rounded,
                  size: 22, color: blinkOn ? AppColors.danger : AppColors.danger.withValues(alpha: 0.25)),
            const SizedBox(width: 12),
            if (snap.highBeams)
              const Icon(Icons.highlight, size: 22, color: AppColors.primary),
            if (snap.lowBeams)
              const Icon(Icons.lightbulb, size: 22, color: AppColors.warning),
            if (snap.fogLights)
              const Icon(Icons.water_drop, size: 22, color: AppColors.purple),
            const SizedBox(width: 12),
            if (snap.alarmArmed)
              const Icon(Icons.security, size: 22, color: AppColors.danger),
            if (snap.locked)
              const Icon(Icons.lock, size: 22, color: AppColors.accent),
            if (snap.doors.any((d) => d.open))
              const Icon(Icons.meeting_room, size: 22, color: AppColors.danger),
          ],
        );
      },
    );
  }
}
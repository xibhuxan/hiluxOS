import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../vehicle_provider.dart';
import 'animated_gauge.dart';
import 'dashboard_widgets.dart';

/// The pretty face: speed + RPM gauges, fuel / coolant / battery metrics,
/// cluster tell-tales. [onFullscreen] enters the shell's tap-to-exit
/// full-screen mode (null inside it, so no button shows there).
class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.snap, this.onFullscreen});

  final VehicleSnapshot snap;
  final VoidCallback? onFullscreen;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 640;
              final speedGauge = AnimatedGauge(
                value: (snap.speedKmh ?? 0).toDouble(),
                max: 160,
                unit: 'km/h',
              );
              final rpmGauge = AnimatedGauge(
                value: (snap.rpm ?? 0).toDouble(),
                max: 4000,
                unit: 'rpm',
                redlineFrom: 3200,
              );
              final metrics = DashboardMetrics(snap: snap);
              final telltales = ClusterTelltaleRow(snap: snap);

              if (wide) {
                return Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: speedGauge))),
                          SizedBox(width: 260, child: metrics),
                          Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: rpmGauge))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    telltales,
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: speedGauge))),
                        Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: rpmGauge))),
                      ],
                    ),
                  ),
                  metrics,
                  const SizedBox(height: 8),
                  telltales,
                ],
              );
            },
          ),
        ),
        if (onFullscreen != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: const Icon(Icons.fullscreen, color: AppColors.muted),
              onPressed: onFullscreen,
              tooltip: 'Pantalla completa',
            ),
          ),
      ],
    );
  }
}
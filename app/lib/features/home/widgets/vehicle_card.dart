import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';

/// Vehicle card. v0.1: the vehicle (OBD-II) is not connected yet.
/// Future: battery voltage, engine temp, fuel, RPM, speed, OBD errors, ACC state.
class VehicleCard extends ConsumerWidget {
  const VehicleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: const Text('OBD-II',
                    style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.link_off, color: AppColors.muted.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              const Text('No conectado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 2),
          const Text('Conecta un adaptador OBD-II',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
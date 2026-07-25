import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/animated_counter.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../core/widgets/progress_bar.dart';
import '../../system_info/system_polling_provider.dart';

/// System plasmoid: RAM + CPU load + temperature, all live and animated.
class SystemWidget extends ConsumerWidget {
  const SystemWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(systemPollingProvider).resources;
    final ram = res?.memoryUsagePercent ?? 0;
    final temp = res?.temperature;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: AppColors.accent),
              const SizedBox(width: 8),
              const Text('Sistema',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(Icons.bolt, color: AppColors.usageColor(ram / 100), size: 18),
            ],
          ),
          const SizedBox(height: 18),
          _Metric(
            label: 'Memoria',
            counter: AnimatedCounter(
              value: ram,
              builder: (v) => '${v.toStringAsFixed(0)}%',
            ),
            bar: AnimatedProgressBar(value: ram / 100),
          ),
          const SizedBox(height: 14),
          _Metric(
            label: 'Carga CPU',
            counter: AnimatedCounter(
              value: res == null ? 0 : res.load1m,
              builder: (v) => v.toStringAsFixed(2),
            ),
            bar: AnimatedProgressBar(
              value: res == null ? 0 : (res.load1m / res.cpuCount).clamp(0.0, 1.0),
              color: AppColors.usageColor(res == null ? 0 : res.load1m / res.cpuCount),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Temperatura', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: temp == null ? AppColors.muted : AppColors.tempColor(temp),
                  fontWeight: FontWeight.w600,
                ),
                child: AnimatedCounter(
                  value: temp ?? 0,
                  builder: (v) => '${v.toStringAsFixed(0)} °C',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.counter, required this.bar});
  final String label;
  final Widget counter;
  final Widget bar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            DefaultTextStyle.merge(
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              child: counter,
            ),
          ],
        ),
        const SizedBox(height: 6),
        bar,
      ],
    );
  }
}
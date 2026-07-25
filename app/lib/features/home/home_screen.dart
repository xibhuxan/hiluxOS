import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../features/system_info/health_provider.dart';
import '../../features/tasks/tasks_provider.dart';
import 'widgets/estado_actual_card.dart';
import 'widgets/pendientes_card.dart';
import 'widgets/system_widget.dart';
import 'widgets/vehicle_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextLine = _contextLine(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Small header + contextual one-liner (evolves toward the AI assistant).
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text('Inicio',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 2)),
            const SizedBox(width: 12),
            const Text('·', style: TextStyle(color: AppColors.surfaceVariant)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(contextLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: AppColors.onBackground)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2x2 grid of cards filling the available space (no scroll).
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              final tall = constraints.maxHeight > 360;
              const gap = 14.0;
              final cards = [
                const StaggeredEntrance(index: 0, child: EstadoActualCard()),
                const StaggeredEntrance(index: 1, child: SystemWidget()),
                const StaggeredEntrance(index: 2, child: VehicleCard()),
                const StaggeredEntrance(index: 3, child: PendientesCard()),
              ];
              if (wide && tall) {
                return Column(
                  children: [
                    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), const SizedBox(width: gap), Expanded(child: cards[1])])),
                    const SizedBox(height: gap),
                    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[2]), const SizedBox(width: gap), Expanded(child: cards[3])])),
                  ],
                );
              }
              // Narrow or short: single column, 2 rows of 2 still if wide.
              if (wide) {
                return Column(
                  children: [
                    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[0]), const SizedBox(width: gap), Expanded(child: cards[1])])),
                    const SizedBox(height: gap),
                    Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: cards[2]), const SizedBox(width: gap), Expanded(child: cards[3])])),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(height: gap),
                  Expanded(child: cards[1]),
                  const SizedBox(height: gap),
                  Expanded(child: cards[2]),
                  const SizedBox(height: gap),
                  Expanded(child: cards[3]),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _contextLine(WidgetRef ref) {
    final tasks = ref.watch(tasksProvider).tasks;
    final health = ref.watch(healthProvider);
    if (!health.ok) return 'Backend desconectado. Revisa el servicio.';
    if (!health.databaseOk) return 'La base de datos está desconectada.';
    if (tasks.isNotEmpty) {
      return 'Tienes ${tasks.length} tareas pendientes. Próxima: ${tasks.first.title}.';
    }
    return 'Todo listo para salir.';
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../tasks/tasks_provider.dart';

/// Pending actions / reminders. Not a calendar — a short to-do list.
class PendientesCard extends ConsumerWidget {
  const PendientesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider).tasks;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note, color: AppColors.purple),
              const SizedBox(width: 8),
              const Text('Pendientes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (tasks.isNotEmpty)
                Text('${tasks.length}',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tasks.isEmpty
                ? const Center(
                    child: Text('No hay tareas pendientes',
                        style: TextStyle(color: AppColors.muted)),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: AppColors.surfaceVariant, height: 1),
                    itemBuilder: (context, i) {
                      final t = tasks[i];
                      return Row(
                        children: [
                          Icon(_kindIcon(t.kind), size: 16, color: AppColors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(t.title,
                                style: const TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          if (t.value != null && t.value!.isNotEmpty)
                            Text(t.value!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => ref.read(tasksProvider.notifier).complete(t),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.check_circle_outline,
                                  size: 18, color: AppColors.accent),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'date':
        return Icons.calendar_today_outlined;
      case 'km':
        return Icons.speed_outlined;
      case 'version':
        return Icons.system_update_outlined;
      default:
        return Icons.task_alt;
    }
  }
}
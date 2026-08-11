import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../tasks/tasks_provider.dart';
import '../../tasks/task.dart';
import 'task_dialog.dart';

/// Pending actions / reminders. Not a calendar — a short to-do list.
/// Supports create (+), edit (tap on the row title) and delete (trash icon).
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
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _onAdd(context, ref),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.add, size: 20, color: AppColors.purple),
                ),
              ),
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
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.surfaceVariant, height: 1),
                    itemBuilder: (context, i) {
                      final t = tasks[i];
                      return Row(
                        children: [
                          Icon(taskKindIcon(t.kind),
                              size: 16, color: AppColors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => _onEdit(context, ref, t),
                              child: Text(t.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                          ),
                          if (t.value != null && t.value!.isNotEmpty)
                            Text(t.value!,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          const SizedBox(width: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _onDelete(context, ref, t),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.delete_outline,
                                  size: 16, color: AppColors.muted),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () =>
                                ref.read(tasksProvider.notifier).complete(t),
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

  Future<void> _onAdd(BuildContext context, WidgetRef ref) async {
    final result = await showTaskDialog(context);
    if (result == null) return;
    await ref.read(tasksProvider.notifier).create(
          title: result.title,
          kind: result.kind,
          value: result.value,
          priority: result.priority,
        );
  }

  Future<void> _onEdit(BuildContext context, WidgetRef ref, Task task) async {
    final result = await showTaskDialog(context, task: task);
    if (result == null) return;
    await ref
        .read(tasksProvider.notifier)
        .update(task.copyWith(
          title: result.title,
          kind: result.kind,
          value: result.value,
          priority: result.priority,
        ));
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDeleteTaskDialog(context, task);
    if (!confirmed) return;
    await ref.read(tasksProvider.notifier).remove(task);
  }
}
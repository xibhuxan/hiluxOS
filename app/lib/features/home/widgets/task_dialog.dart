import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../tasks/task.dart';

/// Result of [showTaskDialog]. The caller decides create vs update.
class TaskDialogResult {
  const TaskDialogResult({
    required this.title,
    required this.kind,
    required this.value,
    required this.priority,
  });
  final String title;
  final String kind;
  final String value;
  final int priority;
}

/// kind options matching the backend (date | km | version | none).
const List<(String value, String label, IconData icon)> _kinds = [
  ('none', 'General', Icons.task_alt),
  ('date', 'Fecha', Icons.calendar_today_outlined),
  ('km', 'Kilómetros', Icons.speed_outlined),
  ('version', 'Versión', Icons.system_update_outlined),
];

Future<TaskDialogResult?> showTaskDialog(BuildContext context, {Task? task}) =>
    showDialog<TaskDialogResult>(
      context: context,
      builder: (_) => TaskDialog(task: task),
    );

class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, this.task});
  final Task? task;
  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  late final TextEditingController _title;
  late final TextEditingController _value;
  late String _kind;
  late int _priority;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.task?.title ?? '');
    _value = TextEditingController(text: widget.task?.value ?? '');
    _kind = widget.task?.kind ?? 'none';
    _priority = widget.task?.priority ?? 0;
  }

  @override
  void dispose() {
    _title.dispose();
    _value.dispose();
    super.dispose();
  }

  String? get _titleError {
    if (!_touched) return null;
    if (_title.text.trim().isEmpty) return 'El título es obligatorio';
    return null;
  }

  void _submit() {
    setState(() => _touched = true);
    if (_title.text.trim().isEmpty) return;
    Navigator.of(context).pop(TaskDialogResult(
      title: _title.text.trim(),
      kind: _kind,
      value: _value.text.trim(),
      priority: _priority,
    ));
  }
  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(editing ? 'Editar pendiente' : 'Nuevo pendiente',
          style: const TextStyle(color: AppColors.onBackground)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Título',
              labelStyle: const TextStyle(color: AppColors.muted),
              errorText: _titleError,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: AppColors.onBackground),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: InputDecoration(
              labelText: 'Tipo',
              labelStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            dropdownColor: AppColors.surfaceVariant,
            style: const TextStyle(color: AppColors.onBackground),
            items: _kinds
                .map((k) => DropdownMenuItem(
                      value: k.$1,
                      child: Row(children: [
                        Icon(k.$3, size: 18, color: AppColors.purple),
                        const SizedBox(width: 8),
                        Text(k.$2),
                      ]),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _kind = v ?? 'none'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _value,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Detalle (opcional)',
              hintText: _kindHint(_kind),
              labelStyle: const TextStyle(color: AppColors.muted),
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: AppColors.onBackground),
          ),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Prioridad', style: TextStyle(color: AppColors.muted)),
            Expanded(
              child: Slider(
                value: _priority.toDouble(),
                min: 0, max: 5, divisions: 5,
                label: '$_priority',
                activeColor: AppColors.purple,
                onChanged: (v) => setState(() => _priority = v.round()),
              ),
            ),
            SizedBox(width: 28, child: Text('$_priority',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.onBackground, fontWeight: FontWeight.w600))),
          ]),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple, foregroundColor: Colors.black),
          child: Text(editing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }

  String _kindHint(String kind) {
    switch (kind) {
      case 'date': return 'ej. 2026-12-01';
      case 'km': return 'ej. 5000';
      case 'version': return 'ej. v1.2';
      default: return 'ej. Nota libre';
    }
  }
}

/// Confirmation dialog for deleting a task. Returns true if confirmed.
Future<bool> showDeleteTaskDialog(BuildContext context, Task task) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('¿Eliminar pendiente?',
          style: TextStyle(color: AppColors.onBackground)),
      content: Text('«${task.title}» se eliminará permanentemente.',
          style: const TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.muted)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger, foregroundColor: Colors.black),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Icon for a task kind, used by the list tile.
IconData taskKindIcon(String kind) {
  switch (kind) {
    case 'date': return Icons.calendar_today_outlined;
    case 'km': return Icons.speed_outlined;
    case 'version': return Icons.system_update_outlined;
    default: return Icons.task_alt;
  }
}
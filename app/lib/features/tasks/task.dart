class Task {
  final String id;
  final String title;
  final String kind;
  final String? value;
  final bool done;
  final int priority;

  Task({
    required this.id,
    required this.title,
    required this.kind,
    required this.value,
    required this.done,
    required this.priority,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        kind: j['kind'] as String? ?? 'none',
        value: j['value'] as String?,
        done: j['done'] as bool? ?? false,
        priority: j['priority'] as int? ?? 0,
      );
}
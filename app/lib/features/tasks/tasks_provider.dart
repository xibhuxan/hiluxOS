import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'task.dart';

class TasksState {
  final List<Task> tasks;
  final bool loading;
  TasksState({this.tasks = const [], this.loading = false});
}

class TasksNotifier extends StateNotifier<TasksState> {
  TasksNotifier(this._api) : super(TasksState()) {
    load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => load());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> load() async {
    try {
      final res = await _api.get('/tasks');
      final list = (res.data as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      state = TasksState(tasks: list, loading: false);
    } catch (_) {}
  }

  Future<void> complete(Task task) async {
    try {
      await _api.put('/tasks/${task.id}', data: {'done': true});
    } catch (_) {}
    await load();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>(
  (ref) => TasksNotifier(ref.watch(apiClientProvider)),
);
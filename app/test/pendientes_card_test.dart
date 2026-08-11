// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/home/widgets/pendientes_card.dart';
import '../lib/features/tasks/task.dart';
import '../lib/features/tasks/tasks_provider.dart';

void main() {
  // The card uses Expanded inside a Column, so it needs bounded height.
  const box = SizedBox(width: 400, height: 300, child: PendientesCard());

  _Recorded recordedOf(_RecordingTasksNotifier n) => n._recorded;

  testWidgets('PendientesCard shows empty message when there are no tasks',
      (tester) async {
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith(
          (ref) => _RecordingTasksNotifier().._set(const [])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    expect(find.text('No hay tareas pendientes'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('tapping + opens the dialog and creating a task calls create()',
      (tester) async {
    final notifier = _RecordingTasksNotifier();
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith((ref) => notifier.._set(const [])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo pendiente'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Revisar frenos');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Nuevo pendiente'), findsNothing);
    final rec = recordedOf(notifier);
    expect(rec.created, isNotEmpty);
    expect(rec.created.single.title, 'Revisar frenos');
    expect(rec.updated, isEmpty);
    expect(rec.removed, isEmpty);

    container.dispose();
    await tester.pumpAndSettle();
  });
  testWidgets('create dialog blocks submit when title is empty', (tester) async {
    final notifier = _RecordingTasksNotifier();
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith((ref) => notifier.._set(const [])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Crear'));
    await tester.pumpAndSettle();
    expect(find.text('El título es obligatorio'), findsOneWidget);
    expect(find.text('Nuevo pendiente'), findsOneWidget);
    expect(recordedOf(notifier).created, isEmpty);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('tapping a task title opens the edit dialog pre-filled',
      (tester) async {
    final notifier = _RecordingTasksNotifier();
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith((ref) => notifier
        .._set([
          Task(
              id: '1',
              title: 'ITV',
              kind: 'date',
              value: '2026-12-01',
              done: false,
              priority: 3),
        ])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    await tester.tap(find.text('ITV'));
    await tester.pumpAndSettle();
    expect(find.text('Editar pendiente'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'ITV vencida');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Editar pendiente'), findsNothing);
    final rec = recordedOf(notifier);
    expect(rec.updated, isNotEmpty);
    expect(rec.updated.single.title, 'ITV vencida');
    expect(rec.created, isEmpty);
    expect(rec.removed, isEmpty);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'tapping the trash icon opens a confirm dialog and deleting calls remove()',
      (tester) async {
    final notifier = _RecordingTasksNotifier();
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith((ref) => notifier
        .._set([
          Task(
              id: '1',
              title: 'Backup',
              kind: 'none',
              value: null,
              done: false,
              priority: 0),
        ])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('¿Eliminar pendiente?'), findsOneWidget);
    expect(find.textContaining('Backup'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar pendiente?'), findsNothing);
    final rec = recordedOf(notifier);
    expect(rec.removed, isNotEmpty);
    expect(rec.removed.single.id, '1');

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('delete confirm dialog can be cancelled', (tester) async {
    final notifier = _RecordingTasksNotifier();
    final container = ProviderContainer(overrides: [
      tasksProvider.overrideWith((ref) => notifier
        .._set([
          Task(
              id: '1',
              title: 'Backup',
              kind: 'none',
              value: null,
              done: false,
              priority: 0),
        ])),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: box)),
    ));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Eliminar pendiente?'), findsNothing);
    expect(recordedOf(notifier).removed, isEmpty);

    container.dispose();
    await tester.pumpAndSettle();
  });
}

/// Records create/update/remove calls so tests can assert on them.
class _Recorded {
  final List<Task> created = [];
  final List<Task> updated = [];
  final List<Task> removed = [];
}

/// Fake [TasksNotifier] that records CRUD calls instead of hitting the network.
/// `load()` is a no-op so the constructor's polling timer has nothing to do,
/// and `_set()` seeds the state used by the card under test.
class _RecordingTasksNotifier extends TasksNotifier {
  _RecordingTasksNotifier() : super(ApiClient(Dio()));
  final _Recorded _recorded = _Recorded();

  void _set(List<Task> tasks) => state = TasksState(tasks: tasks);

  @override
  Future<void> load() async {}

  @override
  Future<void> create({
    required String title,
    String kind = 'none',
    String? value,
    int priority = 0,
  }) async {
    _recorded.created.add(Task(
      id: 'new',
      title: title,
      kind: kind,
      value: value,
      done: false,
      priority: priority,
    ));
  }

  @override
  Future<void> update(Task task) async {
    _recorded.updated.add(task);
  }

  @override
  Future<void> remove(Task task) async {
    _recorded.removed.add(task);
  }

  @override
  Future<void> complete(Task task) async {}
}
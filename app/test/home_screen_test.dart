// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/core/api/websocket_service.dart';
import '../lib/features/home/home_screen.dart';
import '../lib/features/radio/audio_player_provider.dart';
import '../lib/features/radio/radio_provider.dart';
import '../lib/features/radio/spectrum_provider.dart';
import '../lib/features/system_info/controls_provider.dart';
import '../lib/features/system_info/health_provider.dart';
import '../lib/features/system_info/internet_provider.dart';
import '../lib/features/system_info/quick_panel_provider.dart';
import '../lib/features/system_info/system_polling_provider.dart';
import '../lib/features/tasks/tasks_provider.dart';
import '../lib/features/tasks/task.dart';

/// A no-op WebSocketService for tests (no backend under `flutter test`).
class _NoopWebSocketService extends WebSocketService {
  _NoopWebSocketService() : super(url: 'ws://localhost:3000/events');
  @override
  void connect() {}
  @override
  void send(String event, dynamic data) {}
}

/// A no-op SpectrumNotifier so RadioNotifier can be constructed in tests.
class _NoopSpectrumNotifier extends SpectrumNotifier {
  _NoopSpectrumNotifier() : super(ApiClient(Dio()), _NoopWebSocketService());
  @override
  Future<void> start(String url) async {}
  @override
  Future<void> stop() async {}
}


void main() {
  // Override every polling notifier so no timers are created and no network
  // calls are made. Only healthProvider and tasksProvider are overridden per
  // test with specific states; the rest get a default empty state.
  List<Override> baseOverrides() => [
        internetProvider.overrideWith((ref) => _FakeInternetNotifier()..setState(InternetState())),
        systemPollingProvider.overrideWith((ref) => _FakeSystemPollingNotifier()..setState(SystemPollingState())),
        networkProvider.overrideWith((ref) => _FakeNetworkNotifier()..setState(NetworkState())),
        bluetoothProvider.overrideWith((ref) => _FakeBluetoothNotifier()..setState(BluetoothState())),
        audioProvider.overrideWith((ref) => _FakeAudioNotifier()..setState(AudioState())),
        brightnessProvider.overrideWith((ref) => _FakeBrightnessNotifier()..setState(BrightnessState())),
        radioProvider.overrideWith((ref) => _FakeRadioNotifier()..setState(RadioState())),
      ];

  testWidgets('HomeScreen shows backend-disconnected message when health is down',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ...baseOverrides(),
      healthProvider.overrideWith((ref) => _FakeHealthNotifier()..setState(HealthState())),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pump();

    expect(find.textContaining('Backend desconectado'), findsWidgets);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('HomeScreen shows DB-disconnected message when ok but db is down',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ...baseOverrides(),
      healthProvider.overrideWith(
          (ref) => _FakeHealthNotifier()..setState(HealthState(ok: true, databaseOk: false))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pump();

    expect(find.textContaining('base de datos'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('HomeScreen shows pending tasks count when backend is ok',
      (tester) async {
    final tasks = [
      Task(id: '1', title: 'ITV', kind: 'date', value: '2026-12-01', done: false, priority: 2),
      Task(id: '2', title: 'Aceite', kind: 'km', value: '5000', done: false, priority: 1),
    ];
    final container = ProviderContainer(overrides: [
      ...baseOverrides(),
      healthProvider.overrideWith(
          (ref) => _FakeHealthNotifier()..setState(HealthState(ok: true, databaseOk: true))),
      tasksProvider.overrideWith(
          (ref) => _FakeTasksNotifier()..setState(TasksState(tasks: tasks))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pump();

    expect(find.textContaining('2 tareas pendientes'), findsOneWidget);
    expect(find.textContaining('ITV'), findsWidgets);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('HomeScreen shows all-clear message when no tasks and healthy',
      (tester) async {
    final container = ProviderContainer(overrides: [
      ...baseOverrides(),
      healthProvider.overrideWith(
          (ref) => _FakeHealthNotifier()..setState(HealthState(ok: true, databaseOk: true))),
      tasksProvider.overrideWith(
          (ref) => _FakeTasksNotifier()..setState(TasksState(tasks: const []))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ));
    await tester.pump();

    expect(find.text('Todo listo para salir.'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });
}

// ---- Fake notifiers (no timers, no network) ----
// Each fake extends the real notifier, passes a throwaway ApiClient to the
// super constructor, and immediately overrides the state. dispose() is NOT
// overridden so super.dispose() cancels any timers (there are none because
// the fakes never call refresh()).

class _FakeHealthNotifier extends HealthNotifier {
  _FakeHealthNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(HealthState s) => state = s;
}

class _FakeTasksNotifier extends TasksNotifier {
  _FakeTasksNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load() async {}
  void setState(TasksState s) => state = s;
}

class _FakeInternetNotifier extends InternetNotifier {
  _FakeInternetNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(InternetState s) => state = s;
}

class _FakeSystemPollingNotifier extends SystemPollingNotifier {
  _FakeSystemPollingNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> load() async {}
  void setState(SystemPollingState s) => state = s;
}

class _FakeNetworkNotifier extends NetworkNotifier {
  _FakeNetworkNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(NetworkState s) => state = s;
}

class _FakeBluetoothNotifier extends BluetoothNotifier {
  _FakeBluetoothNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(BluetoothState s) => state = s;
}

class _FakeAudioNotifier extends AudioNotifier {
  _FakeAudioNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(AudioState s) => state = s;
}

class _FakeBrightnessNotifier extends BrightnessNotifier {
  _FakeBrightnessNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(BrightnessState s) => state = s;
}

class _FakeRadioNotifier extends RadioNotifier {
  _FakeRadioNotifier() : super(ApiClient(Dio()), AudioPlayerService(), _NoopSpectrumNotifier());
  void setState(RadioState s) => state = s;
}
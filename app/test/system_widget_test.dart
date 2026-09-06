// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/core/api/websocket_service.dart';
import '../lib/features/home/widgets/system_widget.dart';
import '../lib/features/system_info/controls_provider.dart';
import '../lib/features/system_info/health_provider.dart';
import '../lib/features/system_info/internet_provider.dart';
import '../lib/features/system_info/system_polling_provider.dart';
import '../lib/features/updates/update_provider.dart';

/// A no-op WebSocketService for tests (no backend under `flutter test`).
class _NoopWebSocketService extends WebSocketService {
  _NoopWebSocketService() : super(url: 'ws://localhost:3000/events');
  @override
  void connect() {}
  @override
  void send(String event, dynamic data) {}
}

class _FakeUpdateNotifier extends UpdateNotifier {
  _FakeUpdateNotifier() : super(ApiClient(Dio()), _NoopWebSocketService());
  void seed(UpdateInfo s) => state = s;
}

class _FakeHealthNotifier extends HealthNotifier {
  _FakeHealthNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {}
  void setState(HealthState s) => state = s;
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

void main() {
  testWidgets('version cell shows current version when up to date', (tester) async {
    final container = ProviderContainer(overrides: [
      updateProvider.overrideWith((ref) => _FakeUpdateNotifier()
        ..seed(const UpdateInfo(currentVersion: '0.1.0'))),
      healthProvider.overrideWith(
          (ref) => _FakeHealthNotifier()..setState(HealthState())),
      internetProvider.overrideWith(
          (ref) => _FakeInternetNotifier()..setState(InternetState())),
      systemPollingProvider.overrideWith(
          (ref) => _FakeSystemPollingNotifier()..setState(SystemPollingState())),
      networkProvider.overrideWith(
          (ref) => _FakeNetworkNotifier()..setState(NetworkState())),
      bluetoothProvider.overrideWith(
          (ref) => _FakeBluetoothNotifier()..setState(BluetoothState())),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SystemWidget())),
    ));
    await tester.pump();

    expect(find.text('Versión'), findsOneWidget);
    expect(find.text('0.1.0'), findsOneWidget);
    // No update hint when there is nothing newer.
    expect(find.textContaining('→'), findsNothing);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('version cell shows the upgrade hint when an update is available',
      (tester) async {
    final container = ProviderContainer(overrides: [
      updateProvider.overrideWith((ref) => _FakeUpdateNotifier()
        ..seed(const UpdateInfo(
          currentVersion: '0.1.0',
          latestVersion: '0.2.0',
          updateAvailable: true,
        ))),
      healthProvider.overrideWith(
          (ref) => _FakeHealthNotifier()..setState(HealthState())),
      internetProvider.overrideWith(
          (ref) => _FakeInternetNotifier()..setState(InternetState())),
      systemPollingProvider.overrideWith(
          (ref) => _FakeSystemPollingNotifier()..setState(SystemPollingState())),
      networkProvider.overrideWith(
          (ref) => _FakeNetworkNotifier()..setState(NetworkState())),
      bluetoothProvider.overrideWith(
          (ref) => _FakeBluetoothNotifier()..setState(BluetoothState())),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: SystemWidget())),
    ));
    await tester.pump();

    expect(find.text('0.1.0 → 0.2.0'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });
}

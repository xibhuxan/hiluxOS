// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/system_info/controls_provider.dart';
import '../lib/features/settings/widgets/wifi_section.dart';
import '../lib/features/settings/widgets/bluetooth_section.dart';

void main() {
  testWidgets('WifiSection toggles radio and scans when enabled',
      (tester) async {
    final notifier = _RecordingNetworkNotifier().._set(const NetworkState(wifiEnabled: true));
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) => notifier),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: WifiSection())),
    ));
    // The section auto-scans on init when wifi is enabled.
    await tester.pump();
    expect(notifier.scanned, greaterThanOrEqualTo(1));

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('WifiSection lists networks and opens password dialog on tap',
      (tester) async {
    final notifier = _RecordingNetworkNotifier()
      .._set(const NetworkState(
        wifiEnabled: true,
        networks: [
          WifiNetwork(ssid: 'HomeNet', signal: 84, secure: true),
          WifiNetwork(ssid: 'OpenNet', signal: 40, secure: false),
        ],
      ));
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) => notifier),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: WifiSection())),
    ));
    await tester.pump();

    expect(find.text('HomeNet'), findsOneWidget);
    expect(find.text('OpenNet'), findsOneWidget);

    // Tapping the secure network opens the password dialog (an obscure TextField).
    await tester.tap(find.text('HomeNet'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    // Entering a password and confirming calls connect() with the password.
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Conectar'));
    await tester.pumpAndSettle();
    expect(notifier.connected, hasLength(1));
    expect(notifier.connected.single.ssid, 'HomeNet');
    expect(notifier.connected.single.password, 'secret');

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('WifiSection toggle switch calls toggle()', (tester) async {
    final notifier = _RecordingNetworkNotifier().._set(const NetworkState(wifiEnabled: false));
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) => notifier),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: WifiSection())),
    ));
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(notifier.toggled, 1);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('BluetoothSection lists devices and pairs via PIN dialog',
      (tester) async {
    final notifier = _RecordingBluetoothNotifier()
      .._set(const BluetoothState(
        powered: true,
        devices: [
          BluetoothDevice(mac: 'AA:BB:CC:DD:EE:FF', name: 'Headphones', paired: false),
        ],
      ));
    final container = ProviderContainer(overrides: [
      bluetoothProvider.overrideWith((ref) => notifier),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BluetoothSection())),
    ));
    await tester.pump();

    expect(find.text('Headphones'), findsOneWidget);
    expect(find.text('AA:BB:CC:DD:EE:FF'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);

    // Open the action menu and pick "Emparejar".
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Emparejar').last);
    await tester.pumpAndSettle();

    // The PIN dialog is now open; entering a PIN and confirming calls pair().
    expect(find.text('PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Emparejar'));
    await tester.pumpAndSettle();
    expect(notifier.paired, 1);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('BluetoothSection toggle switch calls toggle()', (tester) async {
    final notifier = _RecordingBluetoothNotifier().._set(const BluetoothState(powered: false));
    final container = ProviderContainer(overrides: [
      bluetoothProvider.overrideWith((ref) => notifier),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BluetoothSection())),
    ));
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(notifier.toggled, 1);

    container.dispose();
    await tester.pumpAndSettle();
  });
}

/// Fake [NetworkNotifier] that records calls instead of hitting the network.
class _RecordingNetworkNotifier extends NetworkNotifier {
  _RecordingNetworkNotifier() : super(ApiClient(Dio()));
  int scanned = 0;
  int toggled = 0;
  final List<({String ssid, String? password})> connected = [];

  void _set(NetworkState s) => state = s;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> toggle() async {
    toggled++;
  }

  @override
  Future<void> scan() async {
    scanned++;
  }

  @override
  Future<void> connect(String ssid, String? password) async {
    connected.add((ssid: ssid, password: password));
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> forget(String ssid) async {}
}

/// Fake [BluetoothNotifier] that records calls instead of hitting the network.
class _RecordingBluetoothNotifier extends BluetoothNotifier {
  _RecordingBluetoothNotifier() : super(ApiClient(Dio()));
  int scanned = 0;
  int toggled = 0;
  int paired = 0;
  int connectedCount = 0;
  int removedCount = 0;

  void _set(BluetoothState s) => state = s;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> toggle() async {
    toggled++;
  }

  @override
  Future<void> scan() async {
    scanned++;
  }

  @override
  Future<void> pair(String mac, String? pin) async {
    paired++;
  }

  @override
  Future<void> connect(String mac) async {
    connectedCount++;
  }

  @override
  Future<void> disconnect(String mac) async {}

  @override
  Future<void> remove(String mac) async {
    removedCount++;
  }
}
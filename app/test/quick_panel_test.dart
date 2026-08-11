// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/system_info/controls_provider.dart';
import '../lib/features/system_info/quick_panel_provider.dart';
import '../lib/layout/widgets/quick_panel.dart';

void main() {
  testWidgets('QuickPanel renders WiFi, Bluetooth, Volume and Brightness tiles',
      (tester) async {
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) =>
          _FakeNetworkNotifier()..setState(NetworkState(wifiEnabled: true, connected: true, ssid: 'HomeNet'))),
      bluetoothProvider.overrideWith((ref) =>
          _FakeBluetoothNotifier()..setState(BluetoothState(powered: false, connected: false))),
      audioProvider.overrideWith((ref) =>
          _FakeAudioNotifier()..setState(AudioState(volume: 45, muted: false))),
      brightnessProvider.overrideWith((ref) =>
          _FakeBrightnessNotifier()..setState(BrightnessState(value: 70))),
    ]);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: QuickPanel())),
    ));
    await tester.pump();

    // Open the panel so the tiles become visible (the panel starts hidden).
    final state = tester.state<QuickPanelState>(find.byType(QuickPanel));
    state.open();
    await tester.pumpAndSettle();

    expect(find.text('WiFi'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);
    expect(find.text('Volumen'), findsOneWidget);
    expect(find.text('Brillo'), findsOneWidget);
    // Volume and brightness values are rendered as rounded numbers.
    expect(find.text('45'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('QuickPanel calls onOpenChanged(true) when opened via open()',
      (tester) async {
    bool? opened;
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) => _FakeNetworkNotifier()..setState(NetworkState())),
      bluetoothProvider.overrideWith((ref) => _FakeBluetoothNotifier()..setState(BluetoothState())),
      audioProvider.overrideWith((ref) => _FakeAudioNotifier()..setState(AudioState(volume: 50))),
      brightnessProvider.overrideWith((ref) => _FakeBrightnessNotifier()..setState(BrightnessState(value: 80))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: QuickPanel(onOpenChanged: (open) => opened = open),
        ),
      ),
    ));
    await tester.pump();

    // Find the QuickPanel state and open it programmatically.
    final state = tester.state<QuickPanelState>(find.byType(QuickPanel));
    state.open();
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(state.isOpen, isTrue);

    container.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets('QuickPanel calls onOpenChanged(false) when closed via close()',
      (tester) async {
    bool? opened;
    final container = ProviderContainer(overrides: [
      networkProvider.overrideWith((ref) => _FakeNetworkNotifier()..setState(NetworkState())),
      bluetoothProvider.overrideWith((ref) => _FakeBluetoothNotifier()..setState(BluetoothState())),
      audioProvider.overrideWith((ref) => _FakeAudioNotifier()..setState(AudioState(volume: 50))),
      brightnessProvider.overrideWith((ref) => _FakeBrightnessNotifier()..setState(BrightnessState(value: 80))),
    ]);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: QuickPanel(onOpenChanged: (open) => opened = open),
        ),
      ),
    ));
    await tester.pump();

    final state = tester.state<QuickPanelState>(find.byType(QuickPanel));
    state.open();
    await tester.pumpAndSettle();
    state.close();
    await tester.pumpAndSettle();

    expect(opened, isFalse);
    expect(state.isOpen, isFalse);

    container.dispose();
    await tester.pumpAndSettle();
  });
}

// ---- Fake notifiers (no timers, no network) ----
// The fakes call super.dispose() so the internal polling timers are cancelled.

class _FakeNetworkNotifier extends NetworkNotifier {
  _FakeNetworkNotifier() : super(ApiClient(Dio()));
  void setState(NetworkState s) => state = s;
}

class _FakeBluetoothNotifier extends BluetoothNotifier {
  _FakeBluetoothNotifier() : super(ApiClient(Dio()));
  void setState(BluetoothState s) => state = s;
}

class _FakeAudioNotifier extends AudioNotifier {
  _FakeAudioNotifier() : super(ApiClient(Dio()));
  void setState(AudioState s) => state = s;
}

class _FakeBrightnessNotifier extends BrightnessNotifier {
  _FakeBrightnessNotifier() : super(ApiClient(Dio()));
  void setState(BrightnessState s) => state = s;
}
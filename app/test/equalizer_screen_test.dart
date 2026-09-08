// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/equalizer/equalizer_provider.dart';
import '../lib/features/equalizer/equalizer_screen.dart';

/// Fake notifier (no network) — same pattern as vehicle_screen_test.
class _FakeEqualizerNotifier extends EqualizerNotifier {
  _FakeEqualizerNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }
  bool refreshCalled = false;
  void setState(EqualizerState s) => state = s;

  // Capture actions for assertions.
  bool? lastEnabled;
  double? lastBalance;
  String? lastPreset;
  bool resetCalled = false;
  int? lastBandIndex;
  double? lastBandGain;

  @override
  Future<void> setEnabled(bool enabled) async {
    lastEnabled = enabled;
    state = state.copyWith(enabled: enabled);
  }

  @override
  Future<void> setBalance(double balance) async {
    lastBalance = balance;
    state = state.copyWith(balance: balance);
  }

  @override
  Future<void> setBandLive(int index, double gain) async {
    lastBandIndex = index;
    lastBandGain = gain;
    final bands = [...state.bands];
    bands[index] = EqBand(freq: bands[index].freq, gain: gain);
    state = state.copyWith(bands: bands);
  }

  @override
  Future<void> applyPreset(String name) async {
    lastPreset = name;
  }

  @override
  Future<void> reset() async {
    resetCalled = true;
  }
}

EqualizerState _state({bool enabled = true, String? activePreset}) => EqualizerState(
      enabled: enabled,
      loading: false,
      available: true,
      activePreset: activePreset,
      bands: const [
        EqBand(freq: 60, gain: 0),
        EqBand(freq: 120, gain: 2),
        EqBand(freq: 250, gain: 0),
        EqBand(freq: 500, gain: -3),
        EqBand(freq: 1000, gain: 0),
        EqBand(freq: 2000, gain: 0),
        EqBand(freq: 4000, gain: 1),
        EqBand(freq: 8000, gain: 0),
      ],
      presets: const [
        EqPreset(name: 'Plano', gains: [0, 0, 0, 0, 0, 0, 0, 0]),
        EqPreset(name: 'Rock', gains: [4, 3, 1, -1, -2, 1, 3, 4]),
      ],
    );

void main() {
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(EqualizerState s, [_FakeEqualizerNotifier? fake]) {
    final f = fake ?? _FakeEqualizerNotifier();
    f.setState(s);
    return ProviderContainer(overrides: [equalizerProvider.overrideWith((ref) => f)]);
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: EqualizerScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders the 8 bands and presets', (tester) async {
    bigViewport(tester);
    final container = containerWith(_state());
    await pump(tester, container);

    // 8 frequency labels.
    expect(find.text('60'), findsOneWidget);
    expect(find.text('1k'), findsOneWidget);
    expect(find.text('8k'), findsOneWidget);
    // Preset chips.
    expect(find.text('Plano'), findsOneWidget);
    expect(find.text('Rock'), findsOneWidget);

    await container.read(equalizerProvider.notifier).refresh();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('tapping a preset applies it', (tester) async {
    bigViewport(tester);
    final fake = _FakeEqualizerNotifier();
    final container = containerWith(_state(), fake);
    await pump(tester, container);

    await tester.tap(find.text('Rock'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastPreset, 'Rock');

    container.dispose();
  });

  testWidgets('the enable switch toggles the EQ', (tester) async {
    bigViewport(tester);
    final fake = _FakeEqualizerNotifier();
    final container = containerWith(_state(), fake);
    await pump(tester, container);

    expect(find.text('Activado'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.lastEnabled, false);

    container.dispose();
  });

  testWidgets('reset button calls reset on the notifier', (tester) async {
    bigViewport(tester);
    final fake = _FakeEqualizerNotifier();
    final container = containerWith(_state(), fake);
    await pump(tester, container);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fake.resetCalled, true);

    container.dispose();
  });

  testWidgets('shows the unavailable state when audio is missing', (tester) async {
    bigViewport(tester);
    final container = containerWith(
      const EqualizerState(loading: false, available: false),
    );
    await pump(tester, container);

    expect(find.text('Audio no disponible'), findsOneWidget);

    container.dispose();
  });

  testWidgets('shows the offline state and retry when the backend is down',
      (tester) async {
    bigViewport(tester);
    final fake = _FakeEqualizerNotifier();
    final container = containerWith(
      const EqualizerState(loading: false, backendReachable: false),
      fake,
    );
    await pump(tester, container);

    // Distinct message from the "audio unavailable" one.
    expect(find.text('Backend no disponible'), findsOneWidget);
    expect(find.text('Audio no disponible'), findsNothing);

    // The retry button re-triggers a refresh.
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.refreshCalled, true);

    container.dispose();
  });
}

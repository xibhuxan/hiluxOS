// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/btmedia/btmedia_provider.dart';
import '../lib/features/btmedia/btmedia_screen.dart';

/// Fake notifier (no network) — same pattern as equalizer_screen_test.
class _FakeBtMediaNotifier extends BtMediaNotifier {
  _FakeBtMediaNotifier() : super(ApiClient(Dio()));
  @override
  Future<void> refresh() async {
    refreshCalled = true;
  }

  bool refreshCalled = false;
  void setState(BtMediaState s) => state = s;

  // Capture actions for assertions.
  bool toggleCalled = false;
  bool nextCalled = false;
  bool previousCalled = false;
  double? lastVolume;

  @override
  Future<void> togglePlayPause() async {
    toggleCalled = true;
    state = state.copyWith(status: state.isPlaying ? 'paused' : 'playing');
  }

  @override
  Future<void> next() async {
    nextCalled = true;
  }

  @override
  Future<void> previous() async {
    previousCalled = true;
  }

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
    state = state.copyWith(volume: volume);
  }
}

BtMediaState _connected({String status = 'playing'}) => BtMediaState(
      loading: false,
      available: true,
      connected: true,
      deviceName: 'Pixel 8 Pro',
      status: status,
      volume: 0.6,
      track: const BtTrack(
        title: 'Radar Love',
        artist: 'Golden Earring',
        album: 'Moontan',
        durationSec: 382,
        positionSec: 122,
      ),
    );

void main() {
  void bigViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  ProviderContainer containerWith(BtMediaState s, [_FakeBtMediaNotifier? fake]) {
    final f = fake ?? _FakeBtMediaNotifier();
    f.setState(s);
    return ProviderContainer(overrides: [btMediaProvider.overrideWith((ref) => f)]);
  }

  Future<void> pump(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: BtMediaScreen())),
    ));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('renders now-playing info and the connected device', (tester) async {
    bigViewport(tester);
    final container = containerWith(_connected());
    await pump(tester, container);

    expect(find.text('Radar Love'), findsOneWidget);
    expect(find.text('Golden Earring'), findsOneWidget);
    expect(find.text('Moontan'), findsOneWidget);
    expect(find.text('Pixel 8 Pro'), findsOneWidget);
    // Position 2:02 / duration 6:22.
    expect(find.text('2:02'), findsOneWidget);
    expect(find.text('6:22'), findsOneWidget);

    container.dispose();
  });

  testWidgets('shows the pause icon while playing', (tester) async {
    bigViewport(tester);
    final container = containerWith(_connected(status: 'playing'));
    await pump(tester, container);

    expect(find.byIcon(Icons.pause), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsNothing);

    container.dispose();
  });

  testWidgets('tapping play-pause toggles playback', (tester) async {
    bigViewport(tester);
    final fake = _FakeBtMediaNotifier();
    final container = containerWith(_connected(status: 'paused'), fake);
    await pump(tester, container);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.toggleCalled, true);

    container.dispose();
  });

  testWidgets('next and previous call the notifier', (tester) async {
    bigViewport(tester);
    final fake = _FakeBtMediaNotifier();
    final container = containerWith(_connected(), fake);
    await pump(tester, container);

    await tester.tap(find.byIcon(Icons.skip_next));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.nextCalled, true);

    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.previousCalled, true);

    container.dispose();
  });

  testWidgets('shows "Sin dispositivo" when no phone is connected', (tester) async {
    bigViewport(tester);
    final container = containerWith(
      const BtMediaState(loading: false, available: true, connected: false),
    );
    await pump(tester, container);

    expect(find.text('Sin dispositivo'), findsOneWidget);
    expect(find.text('Bluetooth no disponible'), findsNothing);

    container.dispose();
  });

  testWidgets('shows "Bluetooth no disponible" when the adapter is missing',
      (tester) async {
    bigViewport(tester);
    final container = containerWith(
      const BtMediaState(loading: false, available: false),
    );
    await pump(tester, container);

    expect(find.text('Bluetooth no disponible'), findsOneWidget);
    expect(find.text('Sin dispositivo'), findsNothing);

    container.dispose();
  });

  testWidgets('offline state retries a refresh', (tester) async {
    bigViewport(tester);
    final fake = _FakeBtMediaNotifier();
    final container = containerWith(
      const BtMediaState(loading: false, backendReachable: false),
      fake,
    );
    await pump(tester, container);

    expect(find.text('Backend no disponible'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.refreshCalled, true);

    container.dispose();
  });
}

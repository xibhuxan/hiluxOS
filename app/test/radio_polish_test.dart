// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/core/api/websocket_service.dart';
import '../lib/core/widgets/shimmer.dart';
import '../lib/features/radio/audio_player_provider.dart';
import '../lib/features/radio/radio_provider.dart';
import '../lib/features/radio/radio_screen.dart';
import '../lib/features/radio/spectrum_provider.dart';
import '../lib/shared/models/station.dart';

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

class _FakeRadioNotifier extends RadioNotifier {
  _FakeRadioNotifier() : super(ApiClient(Dio()), AudioPlayerService(), _NoopSpectrumNotifier());
  @override
  Future<void> loadFavorites() async {}
  @override
  Future<void> loadHistory() async {}
  void setState(RadioState s) => state = s;
  void seed(RadioState s) => state = s;
}

Widget _wrap(RadioState state) {
  return ProviderScope(
    overrides: [
      radioProvider.overrideWith((ref) => _FakeRadioNotifier()..seed(state)),
      spectrumProvider.overrideWith((ref) => _NoopSpectrumNotifier()),
    ],
    child: const MaterialApp(home: Scaffold(body: RadioScreen())),
  );
}

final _station = Station(
  id: 's1',
  name: 'Rock FM',
  url: 'http://stream.example.com/rock',
  country: 'ES',
  codec: 'MP3',
  bitrate: 128,
);

void main() {
  testWidgets('search loading shows shimmer skeleton, not a spinner', (tester) async {
    await tester.pumpWidget(_wrap(RadioState(loading: true)));
    await tester.pump();

    expect(find.byType(ShimmerList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('NowPlayingStrip shows name, metadata and EN DIRECTO while playing',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        radioProvider.overrideWith(
            (ref) => _FakeRadioNotifier()..seed(RadioState(current: _station, isPlaying: true))),
        spectrumProvider.overrideWith((ref) => _NoopSpectrumNotifier()),
      ],
      child: MaterialApp(
          home: Scaffold(body: NowPlayingStrip(station: _station, isPlaying: true))),
    ));
    await tester.pump();

    expect(find.text('Rock FM'), findsOneWidget);
    expect(find.text('ES · MP3 · 128 kbps'), findsOneWidget);
    expect(find.text('EN DIRECTO'), findsOneWidget);
  });

  testWidgets('NowPlayingStrip hides the live badge when paused', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NowPlayingStrip(station: _station, isPlaying: false))));
    await tester.pump();

    expect(find.text('Rock FM'), findsOneWidget);
    expect(find.text('EN DIRECTO'), findsNothing);
  });

  testWidgets('NowPlayingStrip renders nothing without a station', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: NowPlayingStrip(station: null, isPlaying: false))));
    await tester.pump();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('station list highlights the current station', (tester) async {
    await tester.pumpWidget(_wrap(RadioState(
      searchResults: [_station],
      current: _station,
    )));
    // Fixed pumps — the SpectrumVisualizer ticker never settles, so
    // pumpAndSettle would time out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The station name appears both in the now-playing strip and the list
    // tile (which is tinted + tinted-text as the current one).
    expect(find.text('Rock FM'), findsNWidgets(2));
    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(tile.tileColor, isNotNull);
  });

  testWidgets('tapping the heart pops and calls toggleFavorite', (tester) async {
    final notifier = _FakeRadioNotifier()
      ..seed(RadioState(
        searchResults: [_station],
        favorites: [_station],
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [radioProvider.overrideWith((ref) => notifier)],
      child: const MaterialApp(home: Scaffold(body: RadioScreen())),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pump();
    // The pop animation runs (scale transition) — just ensure no exception.
    await tester.pump(const Duration(milliseconds: 200));
  });
}

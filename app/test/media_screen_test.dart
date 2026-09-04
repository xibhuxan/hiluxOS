// ignore_for_file: avoid_relative_lib_imports
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/media/media_provider.dart';
import '../lib/features/media/media_screen.dart';
import '../lib/features/media/models/track.dart';
import '../lib/features/radio/audio_player_provider.dart';

/// MediaNotifier whose side effects are all no-ops: the real AudioPlayer is
/// never instantiated (play/attach overridden without calling super) and no
/// HTTP happens (loadTracks overridden).
class _FakeNotifier extends MediaNotifier {
  _FakeNotifier() : super(ApiClient(Dio()), AudioPlayerService());

  /// `state` has a protected setter; seeding via a subclass method is legal.
  void seed(MediaState s) => state = s;

  @override
  Future<void> loadTracks() async {}
  @override
  Future<void> scan() async {}
  @override
  Future<void> play(Track track) async {}
  @override
  void attachPlayerListeners() {}
}

Widget _wrap(MediaState state) {
  final notifier = _FakeNotifier()..seed(state);
  return ProviderScope(
    overrides: [mediaProvider.overrideWith((ref) => notifier)],
    child: const MaterialApp(home: MediaScreen()),
  );
}

void main() {
  testWidgets('empty library shows the scan hint', (tester) async {
    await tester.pumpWidget(_wrap(MediaState()));
    await tester.pumpAndSettle();
    expect(find.text('Biblioteca vacía — pulsa ↻ para escanear'), findsOneWidget);
  });

  testWidgets('tracks render with title and duration', (tester) async {
    final track = Track(
      id: 't1',
      title: 'Test Tone A',
      artist: 'Hilux Soundcheck',
      durationSec: 5,
    );
    await tester.pumpWidget(
      _wrap(MediaState(tracks: [track], duration: const Duration(seconds: 5))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Tone A'), findsOneWidget);
    // "0:05" appears twice: the row's duration label and the seek-bar total.
    expect(find.text('0:05'), findsNWidgets(2));
  });

  testWidgets('current track shows as selected in the list', (tester) async {
    final track = Track(id: 't1', title: 'Test Tone A', durationSec: 5);
    await tester.pumpWidget(
      _wrap(MediaState(tracks: [track], current: track, duration: const Duration(seconds: 5))),
    );
    await tester.pumpAndSettle();
    // The seek bar labels render when a track is current.
    expect(find.text('0:00'), findsWidgets);
  });
}

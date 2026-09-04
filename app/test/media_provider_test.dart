// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/media/media_provider.dart';
import '../lib/features/media/models/track.dart';
import '../lib/features/radio/audio_player_provider.dart';

/// A Dio that returns a canned JSON payload for every request. Requests are
/// recorded so tests can assert which endpoints the provider called.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);
  final Object? Function(RequestOptions) _handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelToken,
  ) async {
    requests.add(options);
    final body = _handler(options);
    final bytes = utf8.encode(jsonEncode(body));
    return ResponseBody(
      Stream.value(Uint8List.fromList(bytes)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Minimal AudioPlayer fake implementing only what the media provider uses.
/// Records every call so tests assert the exact sequence, without touching
/// a real AudioPlayer (no audio backend exists under `flutter test`). The
/// methods deliberately do NOT call super, so the underlying `late final
/// _player` is never instantiated.
class _RecordingAudio extends AudioPlayerService {
  final calls = <String>[];
  @override
  Future<void> play(String url) async => calls.add('play:$url');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> seek(Duration position) async => calls.add('seek:${position.inSeconds}s');
}

/// MediaNotifier subclass that skips the real AudioPlayer event channels
/// (position/duration/complete streams), which don't exist under test.
class _TestMediaNotifier extends MediaNotifier {
  _TestMediaNotifier(super.api, super.audio);
  @override
  void attachPlayerListeners() {}
}

ApiClient _api(Object? Function(RequestOptions) handler) {
  final dio = Dio()..httpClientAdapter = _FakeAdapter(handler);
  return ApiClient(dio);
}


const trackJson = {
  'id': 't1',
  'title': 'Test Tone A',
  'artist': 'Hilux Soundcheck',
  'album': 'System Test',
  'genre': 'Test',
  'durationSec': 5.0,
  'playCount': 0,
};

void main() {
  group('Track', () {
    test('fromJson parses and displayName joins artist', () {
      final t = Track.fromJson(Map<String, dynamic>.from(trackJson));
      expect(t.id, 't1');
      expect(t.durationSec, 5.0);
      expect(t.displayName, 'Hilux Soundcheck — Test Tone A');
      expect(t.subtitle, 'System Test · Test');
    });

    test('displayName falls back to title without artist', () {
      final t = Track.fromJson({'id': 'x', 'title': 'Solo', 'durationSec': 1});
      expect(t.displayName, 'Solo');
    });
  });

  group('MediaNotifier', () {
    test('loadTracks maps the /media/tracks payload', () async {
      final media = _TestMediaNotifier(_api((_) => [trackJson]), _RecordingAudio());

      await media.loadTracks();

      expect(media.state.tracks, hasLength(1));
      expect(media.state.tracks.first.title, 'Test Tone A');
      expect(media.state.loading, isFalse);
      expect(media.state.error, isNull);
    });

    test('scan calls the scan endpoint and reloads tracks', () async {
      final adapter = _FakeAdapter((o) {
        if (o.path.contains('/media/library/scan')) {
          return {'scanned': 1, 'added': 1, 'updated': 0, 'removed': 0, 'failed': []};
        }
        return [trackJson];
      });
      final media = _TestMediaNotifier(ApiClient(Dio()..httpClientAdapter = adapter), _RecordingAudio());

      await media.scan();

      expect(adapter.requests.any((o) => o.path.contains('/media/library/scan')), isTrue);
      expect(media.state.tracks, hasLength(1));
      expect(media.state.scanning, isFalse);
    });

    test('play streams via the backend URL and records the play', () async {
      final adapter = _FakeAdapter((_) => {});
      final audio = _RecordingAudio();
      final media = _TestMediaNotifier(ApiClient(Dio()..httpClientAdapter = adapter), audio);

      await media.play(Track.fromJson(Map<String, dynamic>.from(trackJson)));

      // Streams go straight to the audio service, not through Dio.
      expect(audio.calls.first, startsWith('play:http'));
      expect(audio.calls.first, contains('/media/stream/t1'));
      // The play was recorded via the API (best-effort).
      expect(adapter.requests.any((o) => o.path.contains('/media/tracks/t1/play')), isTrue);
      expect(media.state.current?.id, 't1');
      expect(media.state.isPlaying, isTrue);
      expect(media.state.duration, const Duration(seconds: 5));
    });

    test('pause/resume/stop keep the current track selected', () async {
      final audio = _RecordingAudio();
      final media = _TestMediaNotifier(_api((_) => {}), audio);
      final t = Track.fromJson(Map<String, dynamic>.from(trackJson));

      await media.play(t);
      await media.pause();
      expect(media.state.isPlaying, isFalse);
      expect(media.state.current, isNotNull);

      await media.resume();
      expect(media.state.isPlaying, isTrue);

      await media.stop();
      expect(media.state.isPlaying, isFalse);
      expect(media.state.current, isNotNull,
          reason: 'stop keeps the track selected (same fix as radio)');
    });

    test('seek delegates to the player', () async {
      final audio = _RecordingAudio();
      final media = _TestMediaNotifier(_api((_) => {}), audio);

      await media.play(Track.fromJson(Map<String, dynamic>.from(trackJson)));
      await media.seek(const Duration(seconds: 2));

      expect(audio.calls, contains('seek:2s'));
      expect(media.state.position, const Duration(seconds: 2));
    });

    test('copyWith error sentinel keeps an error when omitted', () {
      expect(MediaState(error: 'algo').copyWith(loading: true).error, 'algo');
      expect(MediaState(error: 'algo').copyWith(error: null).error, isNull);
    });
  });
}

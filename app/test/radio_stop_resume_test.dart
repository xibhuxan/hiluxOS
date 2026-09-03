// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/core/api/websocket_service.dart';
import '../lib/features/radio/audio_player_provider.dart';
import '../lib/features/radio/radio_provider.dart';
import '../lib/features/radio/spectrum_provider.dart';
import '../lib/shared/models/station.dart';

/// A Dio that answers 200 with an empty JSON object to every request, so
/// RadioNotifier.play() (which posts to /radio/history and loads it back) does
/// not throw under `flutter test` where no backend is running.
Dio _okDio() {
  final dio = Dio();
  dio.httpClientAdapter = _OkAdapter();
  return dio;
}

class _OkAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelToken,
  ) async {
    final body = utf8.encode(jsonEncode(<String, dynamic>{}));
    return ResponseBody(
      Stream.value(Uint8List.fromList(body)),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A no-op WebSocketService that never actually connects (no backend under
/// `flutter test`). Its `events` stream is a broadcast controller that emits
/// nothing, so the spectrum provider simply stays idle.
class _NoopWebSocketService extends WebSocketService {
  _NoopWebSocketService() : super(url: 'ws://localhost:3000/events');
  @override
  void connect() {}
  @override
  void send(String event, dynamic data) {}
}

/// A no-op SpectrumNotifier so RadioNotifier can be constructed in tests
/// without hitting a real backend or WebSocket.
class _NoopSpectrumNotifier extends SpectrumNotifier {
  _NoopSpectrumNotifier() : super(ApiClient(_okDio()), _NoopWebSocketService());
  @override
  Future<void> start(String url) async {}
  @override
  Future<void> stop() async {}
}

/// Records every call to the audio service so we can assert on the exact
/// sequence of play / pause / resume / stop WITHOUT touching a real AudioPlayer
/// (there is no audio backend under `flutter test`). The methods deliberately
/// do NOT call super, so the underlying `late final _player` is never accessed
/// and the real AudioPlayer (which needs a live platform channel) is never
/// instantiated.
class _RecordingAudio extends AudioPlayerService {
  final List<String> calls = [];
  @override
  Future<void> play(String url) async => calls.add('play:$url');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Future<void> stop() async => calls.add('stop');
}

Station _station(String url) => Station(
      id: 's1',
      name: 'Test FM',
      url: url,
      country: 'ES',
    );

void main() {
  test('stop then resume keeps the station selected and replays it '
      '(regression: stop used to clear the current station, forcing the user '
      'to re-pick it just to hear it again)', () async {
    final audio = _RecordingAudio();
    final radio = RadioNotifier(ApiClient(_okDio()), audio, _NoopSpectrumNotifier());

    await radio.play(_station('http://example.com/stream'));
    expect(radio.state.current, isNotNull,
        reason: 'play should set the current station');
    expect(radio.state.isPlaying, isTrue);
    expect(audio.calls.last, startsWith('play:'));

    await radio.stop();
    expect(radio.state.isPlaying, isFalse,
        reason: 'stop should stop playback');
    // The fix: stop must NOT clear the current station. If it did, the
    // now-playing card (and its play button) would disappear and the user
    // would be forced to re-pick the station to hear it again.
    expect(radio.state.current, isNotNull,
        reason: 'stop should keep the current station selected so the play '
            'button stays available');

    await radio.resume();
    expect(radio.state.isPlaying, isTrue,
        reason: 'resume after stop should start playback again');

    // The exact sequence we exercised on the audio service.
    expect(
        audio.calls,
        equals([
          'play:http://example.com/stream',
          'stop',
          'resume',
        ]));
  });

  test('pause then resume keeps the station selected (does not clear it)',
      () async {
    final audio = _RecordingAudio();
    final radio = RadioNotifier(ApiClient(_okDio()), audio, _NoopSpectrumNotifier());

    await radio.play(_station('http://example.com/stream'));
    await radio.pause();
    expect(radio.state.isPlaying, isFalse);
    expect(radio.state.current, isNotNull,
        reason: 'pause should keep the current station selected');

    await radio.resume();
    expect(radio.state.isPlaying, isTrue);
    expect(radio.state.current, isNotNull);

    expect(
        audio.calls,
        equals([
          'play:http://example.com/stream',
          'pause',
          'resume',
        ]));
  });
}


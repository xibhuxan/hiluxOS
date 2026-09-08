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

/// A Dio that answers 200 with an empty JSON object to every request, so
/// RadioNotifier.play() (which posts to /radio/history) does not throw under
/// `flutter test` where no backend is running.
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

/// A WebSocketService that never connects but lets the test push events into a
/// broadcast stream, simulating the backend's `voice_action` broadcasts.
class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService() : super(url: 'ws://localhost:3000/events');
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  @override
  void connect() {}

  @override
  void send(String event, dynamic data) {}

  void emit(Map<String, dynamic> msg) => _controller.add(msg);
}

class _NoopSpectrumNotifier extends SpectrumNotifier {
  _NoopSpectrumNotifier() : super(ApiClient(_okDio()), _FakeWebSocketService());
  @override
  Future<void> start(String url) async {}
  @override
  Future<void> stop() async {}
}

/// Records the audio calls without touching a real AudioPlayer.
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

void main() {
  test('a voice_action radio_play event plays the station locally', () async {
    final ws = _FakeWebSocketService();
    final audio = _RecordingAudio();
    final radio = RadioNotifier(
      ApiClient(_okDio()),
      audio,
      _NoopSpectrumNotifier(),
      ws,
    );

    ws.emit({
      'event': 'voice_action',
      'data': {
        'type': 'radio_play',
        'station': {
          'id': 'st-1',
          'name': 'Los 40',
          'url': 'http://los40.stream',
          'favicon': null,
          'country': 'Spain',
          'codec': 'MP3',
          'bitrate': 128,
          'tags': <String>[],
        },
      },
    });
    // Let the broadcast stream deliver + the async play() complete.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(radio.state.current?.name, 'Los 40');
    expect(radio.state.isPlaying, isTrue);
    expect(audio.calls, contains('play:http://los40.stream'));
  });

  test('a voice_action radio_stop event stops playback', () async {
    final ws = _FakeWebSocketService();
    final audio = _RecordingAudio();
    final radio = RadioNotifier(
      ApiClient(_okDio()),
      audio,
      _NoopSpectrumNotifier(),
      ws,
    );

    ws.emit({
      'event': 'voice_action',
      'data': {'type': 'radio_stop'},
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(radio.state.isPlaying, isFalse);
    expect(audio.calls, contains('stop'));
  });

  test('ignores unrelated websocket events', () async {
    final ws = _FakeWebSocketService();
    final audio = _RecordingAudio();
    final radio = RadioNotifier(
      ApiClient(_okDio()),
      audio,
      _NoopSpectrumNotifier(),
      ws,
    );

    ws.emit({'event': 'notification', 'data': {'foo': 'bar'}});
    ws.emit({'event': 'voice_action', 'data': {'type': 'something_else'}});
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(audio.calls, isEmpty);
    expect(radio.state.current, isNull);
  });
}

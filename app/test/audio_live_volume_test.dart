// ignore_for_file: avoid_relative_lib_imports
import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/api/api_client.dart';
import '../lib/features/system_info/controls_provider.dart';

/// Dio adapter that records every PUT and can block on a gate so tests can
/// keep a request "in flight" and queue live updates behind it.
class _GateAdapter implements HttpClientAdapter {
  int puts = 0;
  final List<String> putBodies = [];
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'PUT') {
      puts++;
      putBodies.add(options.data.toString());
      final g = gate;
      if (g != null) await g.future;
    }
    return ResponseBody.fromString('{"volume":50,"muted":false}', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'setVolumeLive coalesces a fast drag into one in-flight PUT + trailing',
    () async {
      final adapter = _GateAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'))
        ..httpClientAdapter = adapter;
      final notifier = AudioNotifier(ApiClient(dio));
      // Let the constructor's refresh() GET settle.
      await Future<void>.delayed(Duration.zero);

      // Block the first PUT so live updates pile up behind it.
      adapter.gate = Completer<void>();
      final first = notifier.setVolumeLive(10);
      await Future<void>.delayed(Duration.zero); // PUT(10) now in flight

      // Drag continues while busy: values queue, only the latest survives.
      await notifier.setVolumeLive(20);
      await notifier.setVolumeLive(30);

      // The state follows the finger immediately, even mid-flight.
      expect(notifier.state.volume, 30);

      // Release the gate: PUT(10) completes, the loop sends the latest (30).
      adapter.gate!.complete();
      await first;

      expect(adapter.puts, 2, reason: 'one in-flight PUT + one trailing PUT');
      expect(adapter.putBodies, equals(['{volume: 10}', '{volume: 30}']));
      expect(notifier.state.volume, 30);

      notifier.dispose();
    },
  );

  test(
    'setVolumeLive sends nothing extra when the drag value repeats',
    () async {
      final adapter = _GateAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api'))
        ..httpClientAdapter = adapter;
      final notifier = AudioNotifier(ApiClient(dio));
      await Future<void>.delayed(Duration.zero);

      // Two separate live gestures: each starts its own leader PUT. The
      // dedup only applies WITHIN one gesture's trailing queue — no PUT is
      // in flight by then, so the leader fires regardless of repeat.
      await notifier.setVolumeLive(42);
      await notifier.setVolumeLive(42);

      expect(adapter.puts, 2);
      expect(notifier.state.volume, 42);

      notifier.dispose();
    },
  );
}

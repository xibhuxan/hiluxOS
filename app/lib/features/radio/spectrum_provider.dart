import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_service.dart';

/// Unique ID for this client's spectrum listener session.
/// Generated once per app session so the backend can track us across
/// start/stop requests.
String _generateListenerId() {
  final ts = DateTime.now().millisecondsSinceEpoch;
  final rnd = (ts * 7).bitLength; // simple deterministic-ish hash
  return 'flutter-$ts-$rnd';
}

/// State holding the latest 48-band spectrum data from the backend, plus
/// whether real-time analysis is currently active.
class SpectrumState {
  /// 48 normalized band values (0..1) from the backend FFT, or null when
  /// no real data is available (playback stopped or not started).
  final List<double>? bands;

  /// True when the backend's PCM buffer is empty (network underrun).
  /// The visualizer uses this to show a BUFFERING state instead of a
  /// frozen frame — bands are decaying toward silence, not static.
  final bool stale;

  /// True when the backend spectrum pipeline is running for this client.
  final bool active;

  SpectrumState({this.bands, this.stale = false, this.active = false});

  SpectrumState copyWith({List<double>? bands, bool? stale, bool? active}) =>
      SpectrumState(
          bands: bands ?? this.bands,
          stale: stale ?? this.stale,
          active: active ?? this.active);
}

/// Listens to the backend `/events` WebSocket for `spectrum` events and
/// exposes the latest 48-band data. Also manages the backend lifecycle:
/// calls `POST /api/radio/spectrum/start` when analysis should begin and
/// `POST /api/radio/spectrum/stop` when it should end.
class SpectrumNotifier extends StateNotifier<SpectrumState> {
  SpectrumNotifier(this._api, this._ws)
      : _listenerId = _generateListenerId(),
        super(SpectrumState());

  final ApiClient _api;
  final WebSocketService _ws;
  final String _listenerId;

  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _staleTimer;
  String? _currentUrl;

  /// Start backend spectrum analysis for [url] and subscribe to WS events.
  Future<void> start(String url) async {
    if (state.active && url == _currentUrl) return; // already running for this URL

    _currentUrl = url;
    _sub ??= _ws.events.listen(_onEvent);

    try {
      await _api.post(
        '/radio/spectrum/start',
        data: {'url': url, 'listenerId': _listenerId},
      );
    } catch (_) {
      // Non-fatal: visualizer falls back to pseudo mode if backend is unavailable.
    }

    state = state.copyWith(active: true);
  }

  /// Stop backend spectrum analysis and clear the current bands.
  Future<void> stop() async {
    if (!state.active) return;

    _staleTimer?.cancel();
    try {
      await _api.post(
        '/radio/spectrum/stop',
        data: {'url': _currentUrl ?? '', 'listenerId': _listenerId},
      );
    } catch (_) {
      // Non-fatal.
    }

    _currentUrl = null;
    state = state.copyWith(active: false, bands: null);
  }

  void _onEvent(Map<String, dynamic> msg) {
    if (msg['event'] != 'spectrum') return;
    final data = msg['data'];

    // Backend now sends {bands: [...], stale: bool}. For backward-compat,
    // also accept a bare array (stale defaults to false).
    List<double> bands;
    bool stale;
    if (data is Map) {
      final raw = data['bands'];
      if (raw is! List) return;
      bands = raw.map((e) => (e as num).toDouble()).toList(growable: false);
      stale = (data['stale'] as bool?) ?? false;
    } else if (data is List) {
      bands = data.map((e) => (e as num).toDouble()).toList(growable: false);
      stale = false;
    } else {
      return;
    }

    // Reset the stale timer: if no data arrives within 5 s, clear bands so
    // the visualizer falls back to pseudo mode (e.g. stream ended).
    // 5 s tolerates normal network hiccups in internet radio streams.
    _staleTimer?.cancel();
    _staleTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) state = state.copyWith(bands: null);
    });

    if (mounted) state = state.copyWith(bands: bands, stale: stale);
  }

  @override
  void dispose() {
    _staleTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final spectrumProvider = StateNotifierProvider<SpectrumNotifier, SpectrumState>(
  (ref) => SpectrumNotifier(
    ref.watch(apiClientProvider),
    ref.watch(webSocketServiceProvider),
  ),
);

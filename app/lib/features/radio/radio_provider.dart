import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_service.dart';
import '../../shared/models/station.dart';
import 'audio_player_provider.dart';
import 'spectrum_provider.dart';

/// Sentinel for `copyWith(error: ...)`: distinguishes "not passed" (keep the
/// current error) from an explicit `null` (clear the error). Without it, any
/// `copyWith` call that omits `error` silently cleared a previously set error.
const _unsetError = Object();

class RadioState {
  final List<Station> searchResults;
  final List<Station> favorites;
  final List<Station> history;
  final Station? current;
  final bool isPlaying;
  final bool loading;
  final String? error;

  RadioState({
    this.searchResults = const [],
    this.favorites = const [],
    this.history = const [],
    this.current,
    this.isPlaying = false,
    this.loading = false,
    this.error,
  });

  RadioState copyWith({
    List<Station>? searchResults,
    List<Station>? favorites,
    List<Station>? history,
    Station? current,
    bool? isPlaying,
    bool? loading,
    Object? error = _unsetError,
  }) =>
      RadioState(
        searchResults: searchResults ?? this.searchResults,
        favorites: favorites ?? this.favorites,
        history: history ?? this.history,
        current: current ?? this.current,
        isPlaying: isPlaying ?? this.isPlaying,
        loading: loading ?? this.loading,
        error: error == _unsetError ? this.error : error as String?,
      );
}

class RadioNotifier extends StateNotifier<RadioState> {
  RadioNotifier(this._api, this._audio, this._spectrum, [WebSocketService? ws])
      : super(RadioState()) {
    _listenVoice(ws);
  }
  final ApiClient _api;
  final AudioPlayerService _audio;
  final SpectrumNotifier _spectrum;
  StreamSubscription<Map<String, dynamic>>? _voiceSub;

  /// React to the voice assistant: it resolves the station backend-side and
  /// tells us which one to play (playback is local, see AudioPlayerService).
  void _listenVoice(WebSocketService? ws) {
    if (ws == null) return;
    _voiceSub = ws.events.listen((msg) {
      if (msg['event'] != 'voice_action') return;
      final data = msg['data'];
      if (data is! Map<String, dynamic>) return;
      switch (data['type']) {
        case 'radio_play':
          final raw = data['station'];
          if (raw is Map<String, dynamic>) play(Station.fromJson(raw));
          break;
        case 'radio_stop':
          stop();
          break;
      }
    });
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    super.dispose();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) return;
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.get('/radio/stations/search', query: {'q': query});
      final list = (res.data as List<dynamic>)
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(searchResults: list, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> loadFavorites() async {
    try {
      final res = await _api.get('/radio/favorites');
      final list = (res.data as List<dynamic>)
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(favorites: list);
    } catch (_) {}
  }

  Future<void> loadHistory() async {
    try {
      final res = await _api.get('/radio/history');
      final list = (res.data as List<dynamic>)
          .map((e) => Station.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(history: list);
    } catch (_) {}
  }

  Future<void> toggleFavorite(Station station) async {
    final isFav = state.favorites.any((s) => s.url == station.url);
    try {
      if (isFav) {
        await _api.delete('/radio/favorites', query: {'url': station.url});
      } else {
        await _api.post('/radio/favorites', data: station.toJson());
      }
      await loadFavorites();
    } catch (e) {
      state = state.copyWith(error: 'No se pudo actualizar favoritos: $e');
    }
  }

  Future<void> play(Station station) async {
    state = state.copyWith(current: station, isPlaying: true);
    await _audio.play(station.url);
    // Start backend spectrum analysis so the visualizer gets real FFT data.
    _spectrum.start(station.url);
    // Record history — best-effort: a failure here must not interrupt playback.
    try {
      await _api.post('/radio/history', data: station.toJson());
      await loadHistory();
    } catch (_) {}
  }

  Future<void> pause() async {
    await _audio.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _audio.resume();
    state = state.copyWith(isPlaying: true);
    // Resume spectrum analysis if we have a current station.
    if (state.current != null) {
      _spectrum.start(state.current!.url);
    }
  }

  Future<void> stop() async {
    await _audio.stop();
    // Stop backend spectrum analysis — no point decoding audio nobody hears.
    await _spectrum.stop();
    // Keep the current station selected (so the now-playing card and its
    // play button stay visible) — only stop playback. `resume()` will
    // re-load the stream URL. Clearing `current` here is what made the
    // play button disappear and forced the user to re-pick the station.
    state = state.copyWith(isPlaying: false);
  }
}

final radioProvider = StateNotifierProvider<RadioNotifier, RadioState>(
  (ref) => RadioNotifier(
    ref.watch(apiClientProvider),
    ref.watch(audioPlayerProvider),
    ref.watch(spectrumProvider.notifier),
    ref.watch(webSocketServiceProvider),
  ),
);

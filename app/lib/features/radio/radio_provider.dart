import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../shared/models/station.dart';
import 'audio_player_provider.dart';

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
    String? error,
  }) =>
      RadioState(
        searchResults: searchResults ?? this.searchResults,
        favorites: favorites ?? this.favorites,
        history: history ?? this.history,
        current: current ?? this.current,
        isPlaying: isPlaying ?? this.isPlaying,
        loading: loading ?? this.loading,
        error: error,
      );
}

class RadioNotifier extends StateNotifier<RadioState> {
  RadioNotifier(this._api, this._audio) : super(RadioState());
  final ApiClient _api;
  final AudioPlayerService _audio;

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
    if (isFav) {
      await _api.delete('/radio/favorites', query: {'url': station.url});
    } else {
      await _api.post('/radio/favorites', data: station.toJson());
    }
    await loadFavorites();
  }

  Future<void> play(Station station) async {
    state = state.copyWith(current: station, isPlaying: true);
    await _audio.play(station.url);
    await _api.post('/radio/history', data: station.toJson());
    await loadHistory();
  }

  Future<void> pause() async {
    await _audio.pause();
    state = state.copyWith(isPlaying: false);
  }

  Future<void> resume() async {
    await _audio.resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    await _audio.stop();
    state = state.copyWith(isPlaying: false, current: null);
  }
}

final radioProvider = StateNotifierProvider<RadioNotifier, RadioState>(
  (ref) => RadioNotifier(ref.watch(apiClientProvider), ref.watch(audioPlayerProvider)),
);
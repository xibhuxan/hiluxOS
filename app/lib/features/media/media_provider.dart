import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/config.dart';
import '../../features/radio/audio_player_provider.dart';
import 'models/track.dart';

/// Sentinel for `copyWith(error:)`: omitted → keep, null → clear, String → set.
const _unsetError = Object();

class MediaState {
  final List<Track> tracks;
  final Track? current;
  final bool isPlaying;
  final bool loading;
  final bool scanning;
  /// Playback position/duration of the current track, for the seek bar.
  final Duration position;
  final Duration duration;
  final String? error;

  MediaState({
    this.tracks = const [],
    this.current,
    this.isPlaying = false,
    this.loading = false,
    this.scanning = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  MediaState copyWith({
    List<Track>? tracks,
    Track? current,
    bool? isPlaying,
    bool? loading,
    bool? scanning,
    Duration? position,
    Duration? duration,
    Object? error = _unsetError,
  }) =>
      MediaState(
        tracks: tracks ?? this.tracks,
        current: current ?? this.current,
        isPlaying: isPlaying ?? this.isPlaying,
        loading: loading ?? this.loading,
        scanning: scanning ?? this.scanning,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        error: error == _unsetError ? this.error : error as String?,
      );
}

/// Notifier for the local music library. Shares the app's single
/// AudioPlayerService with radio (one audio source at a time).
class MediaNotifier extends StateNotifier<MediaState> {
  MediaNotifier(this._api, this._audio) : super(MediaState());
  final ApiClient _api;
  final AudioPlayerService _audio;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _completeSub;

  /// The backend stream URL for a track (same host as the REST API).
  String _streamUrl(String id) => '${AppConfig.restBase}/media/stream/$id';

  Future<void> loadTracks() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final res = await _api.get('/media/tracks');
      final list = (res.data as List<dynamic>)
          .map((e) => Track.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(tracks: list, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: 'No se pudo cargar la biblioteca: $e');
    }
  }

  /// Trigger a backend library rescan and reload the list.
  Future<void> scan() async {
    state = state.copyWith(scanning: true, error: null);
    try {
      await _api.post('/media/library/scan');
      await loadTracks();
    } catch (e) {
      state = state.copyWith(error: 'Error al escanear: $e');
    } finally {
      state = state.copyWith(scanning: false);
    }
  }

  Future<void> play(Track track) async {
    state = state.copyWith(
      current: track,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration(seconds: track.durationSec.round()),
      error: null,
    );
    await _audio.play(_streamUrl(track.id));
    attachPlayerListeners();
    // Record the play — best-effort, never interrupts playback.
    try {
      await _api.post('/media/tracks/${track.id}/play');
    } catch (_) {}
  }

  /// (Re)attach the audioplayers position/duration/complete listeners.
  /// Protected seam: tests subclass MediaNotifier to no-op this (the real
  /// AudioPlayer's event channels don't exist under `flutter test`).
  void attachPlayerListeners() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    _posSub = _audio.player.onPositionChanged.listen((p) {
      state = state.copyWith(position: p);
    });
    _durSub = _audio.player.onDurationChanged.listen((d) {
      state = state.copyWith(duration: d);
    });
    _completeSub = _audio.player.onPlayerComplete.listen((_) {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    });
  }

  Future<void> pause() async {
    await _audio.pause();
    state = state.copyWith(isPlaying: false);
  }

  /// Resume after pause. (The audio service handles the stop-source case.)
  Future<void> resume() async {
    if (state.current == null) return;
    await _audio.resume();
    state = state.copyWith(isPlaying: true);
  }

  Future<void> stop() async {
    await _audio.stop();
    state = state.copyWith(isPlaying: false, position: Duration.zero);
  }

  /// Seek within the current track (HTTP Range on the backend).
  Future<void> seek(Duration target) async {
    if (state.current == null) return;
    await _audio.seek(target);
    state = state.copyWith(position: target);
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _completeSub?.cancel();
    super.dispose();
  }
}

final mediaProvider = StateNotifierProvider<MediaNotifier, MediaState>(
  (ref) => MediaNotifier(
    ref.watch(apiClientProvider),
    ref.watch(audioPlayerProvider),
  ),
);

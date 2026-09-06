import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/utils/config.dart';
import '../../features/radio/audio_player_provider.dart';
import 'models/media_folder.dart';
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
  /// The list the current track was started from. `next()`/auto-advance pick
  /// the next entry in it (or a random one when shuffle is on).
  final List<Track> queue;
  final bool shuffle;
  /// Configured library folders (see GET /media/folders). Missing ones
  /// (exists == false) render with a warning marker in the rail.
  final List<MediaFolder> folders;
  /// True while a folder add/remove is in flight (disables the rail buttons).
  final bool foldersBusy;

  MediaState({
    this.tracks = const [],
    this.current,
    this.isPlaying = false,
    this.loading = false,
    this.scanning = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.queue = const [],
    this.shuffle = false,
    this.folders = const [],
    this.foldersBusy = false,
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
    List<Track>? queue,
    bool? shuffle,
    List<MediaFolder>? folders,
    bool? foldersBusy,
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
        queue: queue ?? this.queue,
        shuffle: shuffle ?? this.shuffle,
        folders: folders ?? this.folders,
        foldersBusy: foldersBusy ?? this.foldersBusy,
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

  /// Load the configured library folders (with the on-disk exists flag).
  Future<void> loadFolders() async {
    try {
      final res = await _api.get('/media/folders');
      final list = (res.data as List<dynamic>)
          .map((e) => MediaFolder.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(folders: list);
    } catch (_) {
      // Folder loading must not break the library — the rail just stays
      // as-is (folders from the last successful load).
    }
  }

  /// Add a library folder (absolute path). On success reloads folders and
  /// triggers a scan so its files are indexed right away. Returns an error
  /// message for the UI, or null on success.
  Future<String?> addFolder(String path) async {
    state = state.copyWith(foldersBusy: true);
    try {
      await _api.post('/media/folders', data: {'path': path});
      await loadFolders();
      await scan();
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        return 'Esa carpeta ya está en la biblioteca';
      }
      return 'No se pudo añadir la carpeta: ${_errMsg(e)}';
    } catch (e) {
      return 'No se pudo añadir la carpeta: ${_errMsg(e)}';
    } finally {
      state = state.copyWith(foldersBusy: false);
    }
  }

  /// Remove a folder (the backend purges its tracks from the index) and
  /// reload the library. Returns an error message for the UI, or null.
  Future<String?> removeFolder(String id) async {
    state = state.copyWith(foldersBusy: true);
    try {
      await _api.delete('/media/folders/$id');
      await loadFolders();
      await loadTracks();
      return null;
    } catch (e) {
      return 'No se pudo quitar la carpeta: ${_errMsg(e)}';
    } finally {
      state = state.copyWith(foldersBusy: false);
    }
  }

  /// Compact, user-friendly message from a Dio error.
  String _errMsg(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) return data['message'] as String;
    }
    return '$e';
  }

  /// Start a track, remembering the list it came from so `next()` (and
  /// auto-advance on completion) can continue through it.
  Future<void> play(Track track, {List<Track>? fromQueue}) async {
    final queue = (fromQueue ?? state.queue).isNotEmpty
        ? (fromQueue ?? state.queue)
        : [track];
    state = state.copyWith(
      current: track,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration(seconds: track.durationSec.round()),
      error: null,
      queue: queue,
    );
    await _audio.play(_streamUrl(track.id));
    attachPlayerListeners();
    // Record the play — best-effort, never interrupts playback.
    try {
      await _api.post('/media/tracks/${track.id}/play');
    } catch (_) {}
  }

  /// Jump to the next queue entry (random one if shuffle is on). Returns
  /// false (and stops) at the end of the queue so callers can rely on it.
  Future<bool> next() async {
    final queue = state.queue;
    final current = state.current;
    if (queue.isEmpty || current == null) return false;
    Track? pick;
    if (state.shuffle) {
      final candidates = queue.where((t) => t.id != current.id).toList();
      if (candidates.isEmpty) return false;
      pick = candidates[_rnd.nextInt(candidates.length)];
    } else {
      final i = queue.indexWhere((t) => t.id == current.id);
      if (i < 0 || i + 1 >= queue.length) return false;
      pick = queue[i + 1];
    }
    await play(pick);
    return true;
  }

  /// Jump to the previous queue entry (no-op at the head of the queue).
  Future<void> previous() async {
    final queue = state.queue;
    final current = state.current;
    if (queue.isEmpty || current == null) return;
    final i = queue.indexWhere((t) => t.id == current.id);
    if (i > 0) await play(queue[i - 1]);
  }

  /// Toggle shuffle. When turning it off, re-seed with a determinist… no: keep
  /// the queue as-is; order resumes deterministically from the current track.
  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  final _rnd = Random();

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
    _completeSub = _audio.player.onPlayerComplete.listen((_) async {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
      // Auto-advance: continue the queue (random entry when shuffle is on).
      await next();
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

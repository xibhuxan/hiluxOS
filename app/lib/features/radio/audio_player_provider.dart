import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps the AudioPlayer so providers can drive playback. The backend returns
/// stream URLs and Flutter does the actual playback (see ARCHITECTURE.md).
class AudioPlayerService {
  /// [player] is injectable so tests can pass a fake AudioPlayer (the real
  /// one needs a live platform channel which isn't available under
  /// `flutter test`). In production it defaults to a lazily-created
  /// [AudioPlayer]; the lazy init means a fully-overridden fake subclass never
  /// instantiates the real player at all.
  AudioPlayerService([AudioPlayer? player]) : _injected = player;

  final AudioPlayer? _injected;
  /// Lazily created so a test fake that overrides every method never touches
  /// the real [AudioPlayer] (which needs a live platform channel).
  late final AudioPlayer _player = _injected ?? AudioPlayer();

  bool _playing = false;
  /// The URL of the station currently loaded (or last loaded) in the player.
  /// Kept across `stop()` so `resume()` can re-load the stream: `audioplayers`
  /// on Linux releases the source on `stop()`, which makes a bare `resume()` a
  /// silent no-op. Only cleared by `play(url)` switching to a new station.
  String? _currentUrl;
  /// True when the underlying player has released its source (after `stop()`),
  /// meaning a `resume()` must re-load the URL rather than just unpause.
  bool _stopped = false;
  /// True once the underlying player reported completion of a local file.
  /// Like `stop()`, the source is released at that point, so a later `resume()`
  /// must re-load the URL (from the start) instead of a bare no-op resume.
  /// Without this flag, resume() after completion hit the `_playing` guard and
  /// silently did nothing (the big play button did nothing after a track ended).
  bool _completed = false;
  StreamSubscription? _completeSub;

  bool get isPlaying => _playing;
  AudioPlayer get player => _player;

  /// Watch completion of the loaded source so `resume()` after a finished
  /// track re-loads it from the start instead of no-op'ing. Subscribed once,
  /// right next to the lazy player creation (the only place the real player
  /// materializes; test fakes never trigger it).
  AudioPlayer get _livePlayer {
    if (!_completeBound) {
      _completeBound = true;
      _completeSub = _player.onPlayerComplete.listen((_) {
        _playing = false;
        _completed = true;
      });
    }
    return _player;
  }

  bool _completeBound = false;

  Future<void> play(String url) async {
    final p = _livePlayer;
    await p.stop();
    await p.play(UrlSource(url));
    _currentUrl = url;
    _stopped = false;
    _completed = false;
    _playing = true;
  }

  Future<void> pause() async {
    await _livePlayer.pause();
    _playing = false;
    _stopped = false;
  }

  /// Resume playback. After `stop()` — or after a local file finished playing
  /// naturally — the underlying player has released its source (on Linux), so
  /// a bare `_player.resume()` is a silent no-op: we re-load the last URL via
  /// `play()` instead (for a finished file that restarts it from the start).
  /// After a `pause()` the source is still loaded, so a true `resume()` is used.
  Future<void> resume() async {
    if (_currentUrl == null) return;
    if (_playing) return;
    if (_stopped || _completed) {
      final p = _livePlayer;
      await p.play(UrlSource(_currentUrl!));
      _stopped = false;
      _completed = false;
    } else {
      await _livePlayer.resume();
    }
    _playing = true;
  }

  Future<void> stop() async {
    await _livePlayer.stop();
    _playing = false;
    // Keep _currentUrl so resume() can re-load the stream; just flag that the
    // source has been released.
    _stopped = true;
  }

  /// Seek within the currently loaded source. Radio streams ignore it; local
  /// media files honor it (the backend serves them with Range support).
  Future<void> seek(Duration position) async {
    await _livePlayer.seek(position);
  }

  void dispose() {
    _completeSub?.cancel();
    _player.dispose();
  }
}

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final svc = AudioPlayerService();
  ref.onDispose(svc.dispose);
  return svc;
});
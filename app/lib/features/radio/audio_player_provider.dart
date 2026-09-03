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

  bool get isPlaying => _playing;
  AudioPlayer get player => _player;

  Future<void> play(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
    _currentUrl = url;
    _stopped = false;
    _playing = true;
  }

  Future<void> pause() async {
    await _player.pause();
    _playing = false;
    _stopped = false;
  }

  /// Resume playback. After a `stop()` the underlying player has released its
  /// source (on Linux), so a bare `_player.resume()` is a silent no-op: we
  /// re-load the last URL via `play()` instead. After a `pause()` the source is
  /// still loaded, so a true `resume()` is used.
  Future<void> resume() async {
    if (_currentUrl == null) return;
    if (_playing) return;
    if (_stopped) {
      await _player.play(UrlSource(_currentUrl!));
      _stopped = false;
    } else {
      await _player.resume();
    }
    _playing = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    // Keep _currentUrl so resume() can re-load the stream; just flag that the
    // source has been released.
    _stopped = true;
  }

  void dispose() => _player.dispose();
}

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final svc = AudioPlayerService();
  ref.onDispose(svc.dispose);
  return svc;
});
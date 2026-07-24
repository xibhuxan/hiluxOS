import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps the AudioPlayer so providers can drive playback. The backend returns
/// stream URLs and Flutter does the actual playback (see ARCHITECTURE.md).
class AudioPlayerService {
  AudioPlayerService() : _player = AudioPlayer();

  final AudioPlayer _player;
  bool _playing = false;

  bool get isPlaying => _playing;
  AudioPlayer get player => _player;

  Future<void> play(String url) async {
    await _player.stop();
    await _player.play(UrlSource(url));
    _playing = true;
  }

  Future<void> pause() async {
    await _player.pause();
    _playing = false;
  }

  Future<void> resume() async {
    await _player.resume();
    _playing = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
  }

  void dispose() => _player.dispose();
}

final audioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final svc = AudioPlayerService();
  ref.onDispose(svc.dispose);
  return svc;
});
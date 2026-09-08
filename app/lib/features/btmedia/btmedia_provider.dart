import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Current track metadata (AVRCP).
class BtTrack {
  final String title;
  final String artist;
  final String album;
  final int durationSec;
  final int positionSec;
  const BtTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.durationSec,
    required this.positionSec,
  });

  factory BtTrack.fromJson(Map<String, dynamic> j) => BtTrack(
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        album: j['album'] as String? ?? '',
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
        positionSec: (j['positionSec'] as num?)?.toInt() ?? 0,
      );
}

/// Immutable snapshot of the Bluetooth-media feature.
class BtMediaState {
  final bool available;
  final bool connected;
  final String? deviceName;
  final BtTrack? track;
  final String status; // 'playing' | 'paused' | 'stopped'
  final double volume;
  final bool backendReachable;
  final bool loading;

  const BtMediaState({
    this.available = true,
    this.connected = false,
    this.deviceName,
    this.track,
    this.status = 'stopped',
    this.volume = 0.7,
    this.backendReachable = true,
    this.loading = true,
  });

  bool get isPlaying => status == 'playing';

  BtMediaState copyWith({
    bool? available,
    bool? connected,
    String? Function()? deviceName,
    BtTrack? Function()? track,
    String? status,
    double? volume,
    bool? backendReachable,
    bool? loading,
  }) =>
      BtMediaState(
        available: available ?? this.available,
        connected: connected ?? this.connected,
        deviceName: deviceName != null ? deviceName() : this.deviceName,
        track: track != null ? track() : this.track,
        status: status ?? this.status,
        volume: volume ?? this.volume,
        backendReachable: backendReachable ?? this.backendReachable,
        loading: loading ?? this.loading,
      );
}

class BtMediaNotifier extends StateNotifier<BtMediaState> {
  BtMediaNotifier(this._api) : super(const BtMediaState()) {
    refresh();
  }
  final ApiClient _api;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/btmedia');
      _apply(res.data as Map<String, dynamic>);
      state = state.copyWith(backendReachable: true, loading: false);
    } catch (_) {
      state = state.copyWith(backendReachable: false, loading: false);
    }
  }

  /// Optimistic whole-state replace from a server response.
  void _apply(Map<String, dynamic> d) {
    state = state.copyWith(
      available: d['available'] as bool?,
      connected: d['connected'] as bool?,
      deviceName: () => d['deviceName'] as String?,
      track: () =>
          d['track'] == null ? null : BtTrack.fromJson(d['track'] as Map<String, dynamic>),
      status: d['status'] as String?,
      volume: (d['volume'] as num?)?.toDouble(),
    );
  }

  Future<void> _command(String path) async {
    try {
      final res = await _api.post('/system/btmedia/$path');
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> togglePlayPause() =>
      state.isPlaying ? _command('pause') : _command('play');

  Future<void> next() => _command('next');

  Future<void> previous() => _command('previous');

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    try {
      final res = await _api.put('/system/btmedia/volume', data: {'volume': volume});
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }
}

final btMediaProvider = StateNotifierProvider<BtMediaNotifier, BtMediaState>(
  (ref) => BtMediaNotifier(ref.watch(apiClientProvider)),
);

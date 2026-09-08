import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// One equalizer band (centre frequency + gain in dB).
class EqBand {
  final double freq;
  final double gain;
  const EqBand({required this.freq, required this.gain});

  factory EqBand.fromJson(Map<String, dynamic> j) => EqBand(
        freq: (j['freq'] as num).toDouble(),
        gain: (j['gain'] as num).toDouble(),
      );
}

/// A named, reusable EQ curve.
class EqPreset {
  final String name;
  final List<double> gains;
  final double balance;
  final bool loudness;
  const EqPreset({
    required this.name,
    required this.gains,
    this.balance = 0,
    this.loudness = false,
  });

  factory EqPreset.fromJson(Map<String, dynamic> j) => EqPreset(
        name: j['name'] as String,
        gains: (j['gains'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        loudness: j['loudness'] as bool? ?? false,
      );
}

/// Immutable snapshot of the equalizer feature.
class EqualizerState {
  final bool enabled;
  final List<EqBand> bands;
  final double balance;
  final bool loudness;
  final String? activePreset;
  final List<EqPreset> presets;
  final bool available;
  final double minGain;
  final double maxGain;
  final bool loading;

  const EqualizerState({
    this.enabled = true,
    this.bands = const [],
    this.balance = 0,
    this.loudness = false,
    this.activePreset,
    this.presets = const [],
    this.available = true,
    this.minGain = -12,
    this.maxGain = 12,
    this.loading = true,
  });

  List<double> get gains => bands.map((b) => b.gain).toList();

  EqualizerState copyWith({
    bool? enabled,
    List<EqBand>? bands,
    double? balance,
    bool? loudness,
    String? Function()? activePreset,
    List<EqPreset>? presets,
    bool? available,
    double? minGain,
    double? maxGain,
    bool? loading,
  }) =>
      EqualizerState(
        enabled: enabled ?? this.enabled,
        bands: bands ?? this.bands,
        balance: balance ?? this.balance,
        loudness: loudness ?? this.loudness,
        activePreset: activePreset != null ? activePreset() : this.activePreset,
        presets: presets ?? this.presets,
        available: available ?? this.available,
        minGain: minGain ?? this.minGain,
        maxGain: maxGain ?? this.maxGain,
        loading: loading ?? this.loading,
      );
}
class EqualizerNotifier extends StateNotifier<EqualizerState> {
  EqualizerNotifier(this._api) : super(const EqualizerState()) {
    refresh();
  }
  final ApiClient _api;

  /// In-flight live-update flag + queued band tweak for the drag throttle,
  /// mirroring AudioNotifier.setVolumeLive: one PUT at a time, latest queued.
  bool _liveBusy = false;
  ({int index, double gain})? _liveQueued;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/equalizer');
      final cap = await _api.get('/system/equalizer/capabilities');
      final presets = await _api.get('/system/equalizer/presets');
      state = _fromJson(
        res.data as Map<String, dynamic>,
        cap.data as Map<String, dynamic>,
        presets.data as List<dynamic>,
      );
    } catch (_) {
      state = state.copyWith(loading: false, available: false);
    }
  }

  EqualizerState _fromJson(
    Map<String, dynamic> d,
    Map<String, dynamic> cap,
    List<dynamic> presets,
  ) =>
      EqualizerState(
        enabled: d['enabled'] as bool? ?? true,
        bands: (d['bands'] as List<dynamic>? ?? [])
            .map((e) => EqBand.fromJson(e as Map<String, dynamic>))
            .toList(),
        balance: (d['balance'] as num?)?.toDouble() ?? 0,
        loudness: d['loudness'] as bool? ?? false,
        activePreset: d['activePreset'] as String?,
        presets: presets.map((e) => EqPreset.fromJson(e as Map<String, dynamic>)).toList(),
        available: cap['available'] as bool? ?? true,
        minGain: (cap['minGain'] as num?)?.toDouble() ?? -12,
        maxGain: (cap['maxGain'] as num?)?.toDouble() ?? 12,
        loading: false,
      );

  /// Optimistic whole-state replace from a server response.
  void _apply(Map<String, dynamic> d) {
    state = state.copyWith(
      enabled: d['enabled'] as bool?,
      bands: (d['bands'] as List<dynamic>?)
          ?.map((e) => EqBand.fromJson(e as Map<String, dynamic>))
          .toList(),
      balance: (d['balance'] as num?)?.toDouble(),
      loudness: d['loudness'] as bool?,
      activePreset: () => d['activePreset'] as String?,
    );
  }

  /// Live band-drag: updates the slider immediately and throttles the PUTs
  /// (leader + trailing queue) so a fast drag doesn't flood the backend.
  Future<void> setBandLive(int index, double gain) async {
    final bands = [...state.bands];
    if (index < 0 || index >= bands.length) return;
    bands[index] = EqBand(freq: bands[index].freq, gain: gain);
    state = state.copyWith(bands: bands, activePreset: () => null);

    if (_liveBusy) {
      _liveQueued = (index: index, gain: gain);
      return;
    }
    _liveBusy = true;
    try {
      var next = (index: index, gain: gain);
      while (true) {
        try {
          final res = await _api.put('/system/equalizer/band/${next.index}',
              data: {'gain': next.gain});
          _apply(res.data as Map<String, dynamic>);
        } catch (_) {}
        final queued = _liveQueued;
        _liveQueued = null;
        if (queued == null) break;
        next = queued;
      }
    } finally {
      _liveBusy = false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    try {
      final res = await _api.put('/system/equalizer', data: {'enabled': enabled});
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> setBalance(double balance) async {
    state = state.copyWith(balance: balance);
    try {
      final res = await _api.put('/system/equalizer', data: {'balance': balance});
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> setLoudness(bool loudness) async {
    state = state.copyWith(loudness: loudness);
    try {
      final res = await _api.put('/system/equalizer', data: {'loudness': loudness});
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> applyPreset(String name) async {
    try {
      final res =
          await _api.post('/system/equalizer/presets/$name/apply', data: <String, dynamic>{});
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> reset() async {
    try {
      final res = await _api.post('/system/equalizer/reset');
      _apply(res.data as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Save the current curve as a named preset, then refresh the preset list.
  Future<void> savePreset(String name) async {
    try {
      final res = await _api.put('/system/equalizer/presets/$name', data: {
        'gains': state.gains,
        'balance': state.balance,
        'loudness': state.loudness,
      });
      final presets = (res.data as List<dynamic>)
          .map((e) => EqPreset.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(presets: presets, activePreset: () => name);
    } catch (_) {}
  }
}

final equalizerProvider =
    StateNotifierProvider<EqualizerNotifier, EqualizerState>(
  (ref) => EqualizerNotifier(ref.watch(apiClientProvider)),
);

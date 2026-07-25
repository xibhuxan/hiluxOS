import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ---- Audio ----

class AudioState {
  final int? volume;
  final bool? muted;
  AudioState({this.volume, this.muted});
  AudioState copyWith({int? volume, bool? muted}) =>
      AudioState(volume: volume ?? this.volume, muted: muted ?? this.muted);
}

class AudioNotifier extends StateNotifier<AudioState> {
  AudioNotifier(this._api) : super(AudioState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/audio');
      final d = res.data as Map<String, dynamic>;
      state = AudioState(
        volume: d['volume'] == null ? null : (d['volume'] as num).toInt(),
        muted: d['muted'] as bool?,
      );
    } catch (_) {}
  }

  Future<void> setVolume(int pct) async {
    state = state.copyWith(volume: pct);
    try {
      await _api.put('/system/audio', data: {'volume': pct});
    } catch (_) {}
    await refresh();
  }

  Future<void> toggleMuted() async {
    final next = !(state.muted ?? false);
    state = state.copyWith(muted: next);
    try {
      await _api.put('/system/audio', data: {'muted': next});
    } catch (_) {}
    await refresh();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final audioProvider = StateNotifierProvider<AudioNotifier, AudioState>(
  (ref) => AudioNotifier(ref.watch(apiClientProvider)),
);

// ---- Network (WiFi) ----

class NetworkState {
  final bool? wifiEnabled;
  final bool connected;
  final String? ssid;
  NetworkState({this.wifiEnabled, this.connected = false, this.ssid});
}

class NetworkNotifier extends StateNotifier<NetworkState> {
  NetworkNotifier(this._api) : super(NetworkState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/network');
      final d = res.data as Map<String, dynamic>;
      state = NetworkState(
        wifiEnabled: d['wifiEnabled'] as bool?,
        connected: d['connected'] as bool,
        ssid: d['ssid'] as String?,
      );
    } catch (_) {}
  }

  Future<void> toggle() async {
    final next = !(state.wifiEnabled ?? false);
    try {
      await _api.put('/system/network', data: {'enabled': next});
    } catch (_) {}
    await refresh();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final networkProvider = StateNotifierProvider<NetworkNotifier, NetworkState>(
  (ref) => NetworkNotifier(ref.watch(apiClientProvider)),
);

// ---- Bluetooth ----

class BluetoothState {
  final bool? powered;
  final bool connected;
  BluetoothState({this.powered, this.connected = false});
}

class BluetoothNotifier extends StateNotifier<BluetoothState> {
  BluetoothNotifier(this._api) : super(BluetoothState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/bluetooth');
      final d = res.data as Map<String, dynamic>;
      state = BluetoothState(
        powered: d['powered'] as bool?,
        connected: d['connected'] as bool,
      );
    } catch (_) {}
  }

  Future<void> toggle() async {
    final next = !(state.powered ?? false);
    try {
      await _api.put('/system/bluetooth', data: {'powered': next});
    } catch (_) {}
    await refresh();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final bluetoothProvider = StateNotifierProvider<BluetoothNotifier, BluetoothState>(
  (ref) => BluetoothNotifier(ref.watch(apiClientProvider)),
);
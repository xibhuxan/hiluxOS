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

class WifiNetwork {
  final String ssid;
  final int signal;
  final bool secure;
  final bool inRange;
  const WifiNetwork({required this.ssid, this.signal = 0, this.secure = false, this.inRange = false});

  factory WifiNetwork.fromJson(Map<String, dynamic> j) => WifiNetwork(
        ssid: j['ssid'] as String,
        signal: (j['signal'] as num?)?.toInt() ?? 0,
        secure: j['secure'] as bool? ?? false,
        inRange: j['inRange'] as bool? ?? false,
      );
}

class NetworkState {
  final bool? wifiEnabled;
  final bool connected;
  final String? ssid;
  final List<WifiNetwork> networks;
  final bool scanning;
  final String? error;
  const NetworkState({
    this.wifiEnabled,
    this.connected = false,
    this.ssid,
    this.networks = const [],
    this.scanning = false,
    this.error,
  });

  NetworkState copyWith({
    bool? wifiEnabled,
    bool? connected,
    String? ssid,
    List<WifiNetwork>? networks,
    bool? scanning,
    String? error,
  }) =>
      NetworkState(
        wifiEnabled: wifiEnabled ?? this.wifiEnabled,
        connected: connected ?? this.connected,
        ssid: ssid ?? this.ssid,
        networks: networks ?? this.networks,
        scanning: scanning ?? this.scanning,
        error: error,
      );
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
      state = state.copyWith(
        wifiEnabled: d['wifiEnabled'] as bool?,
        connected: d['connected'] as bool,
        ssid: d['ssid'] as String?,
        error: null,
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

  Future<void> scan() async {
    state = state.copyWith(scanning: true, error: null);
    try {
      final res = await _api.get('/system/network/wifi/scan');
      final list = (res.data as List<dynamic>)
          .map((e) => WifiNetwork.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(networks: list, scanning: false);
    } catch (e) {
      state = state.copyWith(scanning: false, error: e.toString());
    }
  }

  Future<void> connect(String ssid, String? password) async {
    try {
      await _api.post('/system/network/wifi/connect', data: {
        'ssid': ssid,
        if (password != null && password.isNotEmpty) 'password': password,
      });
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> disconnect() async {
    try {
      await _api.post('/system/network/wifi/disconnect');
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> forget(String ssid) async {
    try {
      await _api.post('/system/network/wifi/forget', data: {'ssid': ssid});
      await refresh();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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

class BluetoothDevice {
  final String mac;
  final String name;
  final bool paired;
  final bool connected;
  const BluetoothDevice({
    required this.mac,
    required this.name,
    this.paired = false,
    this.connected = false,
  });

  factory BluetoothDevice.fromJson(Map<String, dynamic> j) => BluetoothDevice(
        mac: j['mac'] as String,
        name: (j['name'] as String?) ?? 'Unknown',
        paired: j['paired'] as bool? ?? false,
        connected: j['connected'] as bool? ?? false,
      );
}

class BluetoothState {
  final bool? powered;
  final bool connected;
  final List<BluetoothDevice> devices;
  final bool scanning;
  final String? error;
  const BluetoothState({
    this.powered,
    this.connected = false,
    this.devices = const [],
    this.scanning = false,
    this.error,
  });

  BluetoothState copyWith({
    bool? powered,
    bool? connected,
    List<BluetoothDevice>? devices,
    bool? scanning,
    String? error,
  }) =>
      BluetoothState(
        powered: powered ?? this.powered,
        connected: connected ?? this.connected,
        devices: devices ?? this.devices,
        scanning: scanning ?? this.scanning,
        error: error,
      );
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
      state = state.copyWith(
        powered: d['powered'] as bool?,
        connected: d['connected'] as bool,
        error: null,
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

  Future<void> scan() async {
    state = state.copyWith(scanning: true, error: null);
    try {
      final res = await _api.get('/system/network/bluetooth/scan');
      final list = (res.data as List<dynamic>)
          .map((e) => BluetoothDevice.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(devices: list, scanning: false);
    } catch (e) {
      state = state.copyWith(scanning: false, error: e.toString());
    }
  }

  Future<void> pair(String mac, String? pin) async {
    try {
      await _api.post('/system/network/bluetooth/pair', data: {
        'mac': mac,
        if (pin != null && pin.isNotEmpty) 'pin': pin,
      });
      await scan();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> connect(String mac) async {
    try {
      await _api.post('/system/network/bluetooth/connect', data: {'mac': mac});
      await scan();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> disconnect(String mac) async {
    try {
      await _api.post('/system/network/bluetooth/disconnect', data: {'mac': mac});
      await scan();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> remove(String mac) async {
    try {
      await _api.post('/system/network/bluetooth/remove', data: {'mac': mac});
      await scan();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
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
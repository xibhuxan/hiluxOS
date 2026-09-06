import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Snapshot served by `GET /vehicle` (backend Vehicle HAL). The app never
/// knows whether the data is simulated or real (Mock First).
class VehicleSnapshot {
  final bool connected;
  final bool ignition;
  final double? batteryVoltage;
  final int? rpm;
  final int? speedKmh;
  final double? coolantTempC;
  final double? fuelLevel;
  final double? odometerKm;
  final bool lowBeams;
  final bool hazard;
  final bool locked;
  final int windowsTotal;
  final int windowsClosed;
  final int doorsTotal;
  final int doorsClosed;

  VehicleSnapshot({
    required this.connected,
    required this.ignition,
    required this.batteryVoltage,
    required this.rpm,
    required this.speedKmh,
    required this.coolantTempC,
    required this.fuelLevel,
    required this.odometerKm,
    required this.lowBeams,
    required this.hazard,
    required this.locked,
    required this.windowsTotal,
    required this.windowsClosed,
    required this.doorsTotal,
    required this.doorsClosed,
  });

  factory VehicleSnapshot.fromJson(Map<String, dynamic> j) {
    final engine = (j['engine'] as Map<String, dynamic>?) ?? const {};
    final lights = (j['lights'] as Map<String, dynamic>?) ?? const {};
    final signals = (j['turnSignals'] as Map<String, dynamic>?) ?? const {};
    final lock = (j['centralLock'] as Map<String, dynamic>?) ?? const {};
    final windows = (j['windows'] as List<dynamic>?) ?? const [];
    final doors = (j['doors'] as List<dynamic>?) ?? const [];
    return VehicleSnapshot(
      connected: j['connected'] as bool? ?? false,
      ignition: j['ignition'] as bool? ?? false,
      batteryVoltage: (j['batteryVoltage'] as num?)?.toDouble(),
      rpm: engine['rpm'] as int?,
      speedKmh: engine['speedKmh'] as int?,
      coolantTempC: (engine['coolantTempC'] as num?)?.toDouble(),
      fuelLevel: (engine['fuelLevel'] as num?)?.toDouble(),
      odometerKm: (engine['odometerKm'] as num?)?.toDouble(),
      lowBeams: lights['low'] as bool? ?? false,
      hazard: signals['hazard'] as bool? ?? false,
      locked: lock['locked'] as bool? ?? false,
      windowsTotal: windows.length,
      windowsClosed: windows.where((w) {
        final pos = (w as Map<String, dynamic>)['position'];
        return pos is num && pos.toDouble() <= 0.01;
      }).length,
      doorsTotal: doors.length,
      doorsClosed: doors.where((d) => !((d as Map<String, dynamic>)['open'] as bool? ?? false)).length,
    );
  }
}

class VehicleState {
  final VehicleSnapshot? snapshot;
  final bool loading;
  final String? error;

  VehicleState({this.snapshot, this.loading = false, this.error});

  VehicleState copyWith({
    VehicleSnapshot? snapshot,
    bool? loading,
    String? error,
  }) =>
      VehicleState(
        snapshot: snapshot ?? this.snapshot,
        loading: loading ?? this.loading,
        error: error,
      );
}

/// Polls `GET /vehicle` every [interval] (3 s — telemetry is fast-moving).
class VehicleNotifier extends StateNotifier<VehicleState> {
  VehicleNotifier(this._api, {this.interval = const Duration(seconds: 3)})
      : super(VehicleState()) {
    load();
    _timer = Timer.periodic(interval, (_) => load());
  }

  final ApiClient _api;
  final Duration interval;
  late final Timer _timer;

  Future<void> load() async {
    try {
      final res = await _api.get('/vehicle');
      state = VehicleState(
        snapshot: VehicleSnapshot.fromJson(res.data as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = VehicleState(
        snapshot: state.snapshot,
        loading: false,
        error: e.toString(),
      );
    }
  }

  // ---- Actions (API Driven: every card action is an API operation) ----

  Future<void> setLights({bool? low, bool? high, bool? position, bool? fog, bool? auxiliary}) async {
    final body = <String, dynamic>{
      'low': ?low,
      'high': ?high,
      'position': ?position,
      'fog': ?fog,
      'auxiliary': ?auxiliary,
    };
    if (body.isEmpty) return;
    try {
      final res = await _api.put('/vehicle/lights', data: body);
      state = VehicleState(
        snapshot: VehicleSnapshot.fromJson(res.data as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setLock(bool locked) async {
    try {
      final res = await _api.put('/vehicle/lock', data: {'locked': locked});
      state = VehicleState(
        snapshot: VehicleSnapshot.fromJson(res.data as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> windowAction(int id, String action) async {
    try {
      final res = await _api.post('/vehicle/windows/$id/$action');
      state = VehicleState(
        snapshot: VehicleSnapshot.fromJson(res.data as Map<String, dynamic>),
        loading: false,
      );
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

final vehicleProvider = StateNotifierProvider<VehicleNotifier, VehicleState>(
  (ref) => VehicleNotifier(ref.watch(apiClientProvider)),
);
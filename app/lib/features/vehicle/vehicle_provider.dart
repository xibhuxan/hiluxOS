import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// One power window, as served by the Vehicle HAL. `position` is 0 (closed)…
/// 1 (fully open); `moving` is null when stopped.
class VehicleWindowInfo {
  final int id;
  final String label;
  final double position;
  final String? moving;

  const VehicleWindowInfo({
    required this.id,
    required this.label,
    required this.position,
    this.moving,
  });

  bool get isClosed => position <= 0.01;
}

/// One door (state + actuation).
class VehicleDoorInfo {
  final int id;
  final String label;
  final bool open;

  const VehicleDoorInfo({required this.id, required this.label, required this.open});
}

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
  final bool positionLights;
  final bool lowBeams;
  final bool highBeams;
  final bool fogLights;
  final bool auxiliaryLights;
  final bool turnLeft;
  final bool turnRight;
  final bool hazard;
  final bool locked;
  final bool alarmArmed;
  final List<VehicleWindowInfo> windows;
  final List<VehicleDoorInfo> doors;

  int get windowsClosed => windows.where((w) => w.isClosed).length;
  int get doorsClosed => doors.where((d) => !d.open).length;

  VehicleSnapshot({
    required this.connected,
    required this.ignition,
    required this.batteryVoltage,
    required this.rpm,
    required this.speedKmh,
    required this.coolantTempC,
    required this.fuelLevel,
    required this.odometerKm,
    required this.positionLights,
    required this.lowBeams,
    required this.highBeams,
    required this.fogLights,
    required this.auxiliaryLights,
    required this.turnLeft,
    required this.turnRight,
    required this.hazard,
    required this.locked,
    required this.alarmArmed,
    required this.windows,
    required this.doors,
  });

  factory VehicleSnapshot.fromJson(Map<String, dynamic> j) {
    final engine = (j['engine'] as Map<String, dynamic>?) ?? const {};
    final lights = (j['lights'] as Map<String, dynamic>?) ?? const {};
    final signals = (j['turnSignals'] as Map<String, dynamic>?) ?? const {};
    final lock = (j['centralLock'] as Map<String, dynamic>?) ?? const {};
    final alarm = (j['alarm'] as Map<String, dynamic>?) ?? const {};
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
      positionLights: lights['position'] as bool? ?? false,
      lowBeams: lights['low'] as bool? ?? false,
      highBeams: lights['high'] as bool? ?? false,
      fogLights: lights['fog'] as bool? ?? false,
      auxiliaryLights: lights['auxiliary'] as bool? ?? false,
      turnLeft: signals['left'] as bool? ?? false,
      turnRight: signals['right'] as bool? ?? false,
      hazard: signals['hazard'] as bool? ?? false,
      locked: lock['locked'] as bool? ?? false,
      alarmArmed: alarm['armed'] as bool? ?? false,
      windows: windows
          .map((w) => VehicleWindowInfo(
                id: (w as Map<String, dynamic>)['id'] as int,
                label: (w)['label'] as String? ?? '',
                position: ((w)['position'] as num?)?.toDouble() ?? 0,
                moving: (w)['moving'] as String?,
              ))
          .toList(),
      doors: doors
          .map((d) => VehicleDoorInfo(
                id: (d as Map<String, dynamic>)['id'] as int,
                label: (d)['label'] as String? ?? '',
                open: (d)['open'] as bool? ?? false,
              ))
          .toList(),
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
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Sets a turn signal. Real-car behaviour: left/right/hazard are mutually
  /// exclusive — sending `left: true` clears right and hazard (the mock driver
  /// resolves this; the UI offers one-shot toggle buttons, not switches).
  Future<void> setSignals({bool? left, bool? right, bool? hazard}) async {
    final body = <String, dynamic>{
      'left': ?left,
      'right': ?right,
      'hazard': ?hazard,
    };
    if (body.isEmpty) return;
    try {
      final res = await _api.put('/vehicle/signals', data: body);
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setLock(bool locked) async {
    try {
      final res = await _api.put('/vehicle/lock', data: {'locked': locked});
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setIgnition(bool on) async {
    try {
      final res = await _api.put('/vehicle/ignition', data: {'on': on});
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setDoor(int id, bool open) async {
    try {
      final res = await _api.put('/vehicle/doors/$id', data: {'open': open});
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> setAlarm(bool armed) async {
    try {
      final res = await _api.put('/vehicle/alarm', data: {'armed': armed});
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> windowAction(int id, String action) async {
    try {
      final res = await _api.post('/vehicle/windows/$id/$action');
      _applySnapshotResponse(res);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Shared success path for every action: the backend returns the full
  /// snapshot after applying the change, so the UI state stays consistent.
  void _applySnapshotResponse(dynamic res) {
    state = VehicleState(
      snapshot: VehicleSnapshot.fromJson(res.data as Map<String, dynamic>),
      loading: false,
    );
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
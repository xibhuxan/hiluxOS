import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Pi power health served by `GET /power` (backend Power HAL).
class PowerHealth {
  final bool available;
  final bool undervoltage;
  final bool frequencyCapped;
  final bool throttled;

  PowerHealth({
    required this.available,
    required this.undervoltage,
    required this.frequencyCapped,
    required this.throttled,
  });

  factory PowerHealth.fromJson(Map<String, dynamic> j) => PowerHealth(
        available: j['available'] as bool? ?? false,
        undervoltage: j['undervoltage'] as bool? ?? false,
        frequencyCapped: j['frequencyCapped'] as bool? ?? false,
        throttled: j['throttled'] as bool? ?? false,
      );
}

class PowerState {
  final PowerHealth? health;
  final String? error;

  PowerState({this.health, this.error});
}

/// Polls `GET /power` every [interval] (30 s — power state changes slowly).
class PowerNotifier extends StateNotifier<PowerState> {
  PowerNotifier(this._api, {this.interval = const Duration(seconds: 30)})
      : super(PowerState()) {
    refresh();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  final ApiClient _api;
  final Duration interval;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/power');
      state = PowerState(
          health: PowerHealth.fromJson(res.data as Map<String, dynamic>));
    } catch (e) {
      state = PowerState(error: e.toString());
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final powerProvider = StateNotifierProvider<PowerNotifier, PowerState>(
  (ref) => PowerNotifier(ref.watch(apiClientProvider)),
);
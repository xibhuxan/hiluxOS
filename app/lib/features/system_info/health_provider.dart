import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

/// Backend /health poller. Exposes whether the API + database are reachable,
/// used by the home "Estado actual" card.
class HealthState {
  final bool ok;
  final bool databaseOk;
  HealthState({this.ok = false, this.databaseOk = false});
}

class HealthNotifier extends StateNotifier<HealthState> {
  HealthNotifier(this._api) : super(HealthState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => refresh());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/health');
      final d = res.data as Map<String, dynamic>;
      final db = d['database'] == 'ok';
      state = HealthState(ok: true, databaseOk: db);
    } catch (_) {
      state = HealthState(ok: false, databaseOk: false);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final healthProvider = StateNotifierProvider<HealthNotifier, HealthState>(
  (ref) => HealthNotifier(ref.watch(apiClientProvider)),
);
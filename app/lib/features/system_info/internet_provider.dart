import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ---- Internet ----

class InternetState {
  final bool reachable;
  final int? latencyMs;
  InternetState({this.reachable = false, this.latencyMs});
}

class InternetNotifier extends StateNotifier<InternetState> {
  InternetNotifier(this._api) : super(InternetState()) {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }
  final ApiClient _api;
  late final Timer _timer;

  Future<void> refresh() async {
    try {
      final res = await _api.get('/system/internet');
      final d = res.data as Map<String, dynamic>;
      state = InternetState(
        reachable: d['reachable'] as bool,
        latencyMs: d['latencyMs'] as int?,
      );
    } catch (_) {
      state = InternetState(reachable: false, latencyMs: null);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final internetProvider = StateNotifierProvider<InternetNotifier, InternetState>(
  (ref) => InternetNotifier(ref.watch(apiClientProvider)),
);

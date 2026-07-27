import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

// ---- Brightness ----

/// Brightness state backed by the /settings/brightness endpoint.
class BrightnessState {
  final int value;
  final bool loading;
  BrightnessState({this.value = 80, this.loading = false});
}

class BrightnessNotifier extends StateNotifier<BrightnessState> {
  BrightnessNotifier(this._api) : super(BrightnessState()) {
    refresh();
  }
  final ApiClient _api;

  Future<void> refresh() async {
    state = BrightnessState(value: state.value, loading: true);
    try {
      final res = await _api.get('/settings/brightness');
      final d = res.data as Map<String, dynamic>;
      final raw = d['value'];
      final v = raw == null ? 80 : int.tryParse(raw.toString()) ?? 80;
      state = BrightnessState(value: v.clamp(0, 100));
    } catch (_) {
      state = BrightnessState(value: state.value);
    }
  }

  Future<void> setBrightness(int pct) async {
    state = BrightnessState(value: pct.clamp(0, 100));
    try {
      await _api.put('/settings/brightness', data: {'value': pct.clamp(0, 100).toString()});
    } catch (_) {}
    await refresh();
  }
}

final brightnessProvider =
    StateNotifierProvider<BrightnessNotifier, BrightnessState>(
  (ref) => BrightnessNotifier(ref.watch(apiClientProvider)),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class SettingsState {
  final Map<String, String> values;
  final bool loading;
  final String? error;
  SettingsState({this.values = const {}, this.loading = false, this.error});
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier(this._api) : super(SettingsState());
  final ApiClient _api;

  Future<void> load() async {
    state = SettingsState(values: state.values, loading: true, error: null);
    try {
      final res = await _api.get('/settings');
      final data = (res.data as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v?.toString() ?? ''),
      );
      state = SettingsState(values: data, loading: false);
    } catch (e) {
      state = SettingsState(values: state.values, loading: false, error: e.toString());
    }
  }

  Future<void> update(String key, String value) async {
    state = SettingsState(values: {...state.values, key: value}, loading: state.loading);
    try {
      await _api.put('/settings/$key', data: {'value': value});
    } catch (e) {
      state = SettingsState(values: state.values, loading: state.loading, error: e.toString());
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(ref.watch(apiClientProvider)),
);
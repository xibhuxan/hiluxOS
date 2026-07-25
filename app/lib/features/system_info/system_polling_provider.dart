import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import 'system_provider.dart';

/// Live system resources, refreshed every [interval]. Used by the shell status
/// panel and the home dashboard system widget.
class SystemPollingState {
  final SystemResources? resources;
  final SystemInfo? info;
  final bool loading;
  final String? error;

  SystemPollingState({this.resources, this.info, this.loading = false, this.error});

  SystemPollingState copyWith({
    SystemResources? resources,
    SystemInfo? info,
    bool? loading,
    String? error,
  }) =>
      SystemPollingState(
        resources: resources ?? this.resources,
        info: info ?? this.info,
        loading: loading ?? this.loading,
        error: error,
      );
}

class SystemPollingNotifier extends StateNotifier<SystemPollingState> {
  SystemPollingNotifier(this._api, {this.interval = const Duration(seconds: 5)})
      : super(SystemPollingState()) {
    load();
    _timer = Timer.periodic(interval, (_) => load());
  }

  final ApiClient _api;
  final Duration interval;
  late final Timer _timer;

  Future<void> load() async {
    try {
      final resRes = await _api.get('/system/resources');
      state = SystemPollingState(
        resources: SystemResources.fromJson(resRes.data as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = SystemPollingState(
        resources: state.resources,
        loading: false,
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final systemPollingProvider =
    StateNotifierProvider<SystemPollingNotifier, SystemPollingState>(
  (ref) => SystemPollingNotifier(ref.watch(apiClientProvider)),
);

/// Live clock (updates every second).
class ClockNotifier extends StateNotifier<DateTime> {
  ClockNotifier() : super(DateTime.now()) {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) state = DateTime.now();
    });
  }
  late final Timer _timer;

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

final clockProvider = StateNotifierProvider<ClockNotifier, DateTime>(
  (ref) => ClockNotifier(),
);
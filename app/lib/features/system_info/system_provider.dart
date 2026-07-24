import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';

class SystemInfo {
  final String hostname;
  final String platform;
  final String arch;
  final int cpus;
  final double totalMemoryMb;
  final int uptimeSeconds;

  SystemInfo({
    required this.hostname,
    required this.platform,
    required this.arch,
    required this.cpus,
    required this.totalMemoryMb,
    required this.uptimeSeconds,
  });

  factory SystemInfo.fromJson(Map<String, dynamic> j) => SystemInfo(
        hostname: j['hostname'] as String,
        platform: j['platform'] as String,
        arch: j['arch'] as String,
        cpus: j['cpus'] as int,
        totalMemoryMb: (j['totalMemoryMb'] as num).toDouble(),
        uptimeSeconds: j['uptimeSeconds'] as int,
      );
}

class SystemResources {
  final double memoryUsagePercent;
  final double freeMemoryMb;
  final double totalMemoryMb;
  final int cpuCount;
  final double? temperature;
  final int uptimeSeconds;

  SystemResources({
    required this.memoryUsagePercent,
    required this.freeMemoryMb,
    required this.totalMemoryMb,
    required this.cpuCount,
    required this.temperature,
    required this.uptimeSeconds,
  });

  factory SystemResources.fromJson(Map<String, dynamic> j) => SystemResources(
        memoryUsagePercent: (j['memoryUsagePercent'] as num).toDouble(),
        freeMemoryMb: (j['freeMemoryMb'] as num).toDouble(),
        totalMemoryMb: (j['totalMemoryMb'] as num).toDouble(),
        cpuCount: j['cpuCount'] as int,
        temperature: (j['temperature'] as num?)?.toDouble(),
        uptimeSeconds: j['uptimeSeconds'] as int,
      );
}

class SystemState {
  final SystemInfo? info;
  final SystemResources? resources;
  final bool loading;
  final String? error;

  SystemState({this.info, this.resources, this.loading = false, this.error});

  SystemState copyWith({
    SystemInfo? info,
    SystemResources? resources,
    bool? loading,
    String? error,
  }) =>
      SystemState(
        info: info ?? this.info,
        resources: resources ?? this.resources,
        loading: loading ?? this.loading,
        error: error,
      );
}

class SystemNotifier extends StateNotifier<SystemState> {
  SystemNotifier(this._api) : super(SystemState());
  final ApiClient _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final infoRes = await _api.get('/system/info');
      final resRes = await _api.get('/system/resources');
      state = SystemState(
        info: SystemInfo.fromJson(infoRes.data as Map<String, dynamic>),
        resources: SystemResources.fromJson(resRes.data as Map<String, dynamic>),
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final systemProvider = StateNotifierProvider<SystemNotifier, SystemState>(
  (ref) => SystemNotifier(ref.watch(apiClientProvider)),
);
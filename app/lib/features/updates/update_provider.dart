import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_service.dart';

/// Update status mirror of the backend's UpdateStatus type.
enum UpdateStatus {
  idle,
  checking,
  downloading,
  verifying,
  applying,
  restarting,
  done,
  failed,
  rolledBack,
}

/// Parse a status string from the backend into the enum.
UpdateStatus _parseStatus(String? s) {
  switch (s) {
    case 'checking':
      return UpdateStatus.checking;
    case 'downloading':
      return UpdateStatus.downloading;
    case 'verifying':
      return UpdateStatus.verifying;
    case 'applying':
      return UpdateStatus.applying;
    case 'restarting':
      return UpdateStatus.restarting;
    case 'done':
      return UpdateStatus.done;
    case 'failed':
      return UpdateStatus.failed;
    case 'rolled_back':
      return UpdateStatus.rolledBack;
    default:
      return UpdateStatus.idle;
  }
}

/// Full update info returned by GET /api/updates.
class UpdateInfo {
  final String currentVersion;
  final String? latestVersion;
  final bool updateAvailable;
  final String? releaseNotes;
  final String? bundleUrl;
  final UpdateStatus status;
  final String? lastError;
  final String? lastAppliedVersion;

  /// Download progress 0-100 (only during downloading).
  final int downloadPercent;

  const UpdateInfo({
    required this.currentVersion,
    this.latestVersion,
    this.updateAvailable = false,
    this.releaseNotes,
    this.bundleUrl,
    this.status = UpdateStatus.idle,
    this.lastError,
    this.lastAppliedVersion,
    this.downloadPercent = 0,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        currentVersion: j['currentVersion'] as String? ?? '0.0.0',
        latestVersion: j['latestVersion'] as String?,
        updateAvailable: j['updateAvailable'] as bool? ?? false,
        releaseNotes: j['releaseNotes'] as String?,
        bundleUrl: j['bundleUrl'] as String?,
        status: _parseStatus(j['status'] as String?),
        lastError: j['lastError'] as String?,
        lastAppliedVersion: j['lastAppliedVersion'] as String?,
      );

  UpdateInfo copyWith({
    UpdateStatus? status,
    int? downloadPercent,
    String? lastError,
  }) =>
      UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        updateAvailable: updateAvailable,
        releaseNotes: releaseNotes,
        bundleUrl: bundleUrl,
        status: status ?? this.status,
        lastError: lastError ?? this.lastError,
        lastAppliedVersion: lastAppliedVersion,
        downloadPercent: downloadPercent ?? this.downloadPercent,
      );
}

class UpdateNotifier extends StateNotifier<UpdateInfo> {
  UpdateNotifier(this._api, this._ws) : super(const UpdateInfo(currentVersion: '0.0.0')) {
    _load();
    _listenWs();
  }

  final ApiClient _api;
  final WebSocketService _ws;
  StreamSubscription<Map<String, dynamic>>? _sub;

  Future<void> _load() async {
    try {
      final res = await _api.get('/updates');
      state = UpdateInfo.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      // ignore — will retry on next action
    }
  }

  void _listenWs() {
    _sub = _ws.events.listen((msg) {
      if (msg['event'] == 'update') {
        final data = msg['data'] as Map<String, dynamic>;
        final event = data['event'] as String?;
        if (event == 'status') {
          final status = _parseStatus(data['status'] as String?);
          state = state.copyWith(status: status);
        } else if (event == 'downloading') {
          final percent = data['percent'] as int?;
          state = state.copyWith(
            status: UpdateStatus.downloading,
            downloadPercent: percent ?? state.downloadPercent,
          );
        } else if (event == 'applied') {
          state = state.copyWith(status: UpdateStatus.applying);
        }
      }
    });
  }

  /// Check for updates.
  Future<void> check() async {
    try {
      final res = await _api.post('/updates/check');
      state = UpdateInfo.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Apply the update (download + verify + install + restart).
  Future<void> apply(String version) async {
    try {
      await _api.post('/updates/apply', data: {'version': version});
      // The backend will restart; the WS will drop and reconnect.
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  /// Roll back to the previous version.
  Future<void> rollback() async {
    try {
      await _api.post('/updates/rollback');
    } catch (e) {
      state = state.copyWith(lastError: e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateInfo>((ref) {
  return UpdateNotifier(ref.watch(apiClientProvider), ref.watch(webSocketServiceProvider));
});
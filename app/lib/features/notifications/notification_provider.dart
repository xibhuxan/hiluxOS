import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/api/websocket_service.dart';
import '../../shared/models/notification.dart';

/// State holder for the notification system.
class NotificationState {
  /// All notifications (newest first).
  final List<AppNotification> items;

  /// Currently visible toast notifications (auto-dismiss).
  final List<AppNotification> toasts;

  const NotificationState({this.items = const [], this.toasts = const []});

  int get unreadCount => items.where((n) => !n.read).length;
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier(this._api, this._ws)
      : super(const NotificationState()) {
    _loadUnread();
    _listenWs();
  }

  final ApiClient _api;
  final WebSocketService _ws;
  StreamSubscription<Map<String, dynamic>>? _sub;

  void _listenWs() {
    _sub = _ws.events.listen((msg) {
      if (msg['event'] == 'notification') {
        final data = msg['data'] as Map<String, dynamic>;
        final notification = AppNotification.fromJson(data);
        // Prepend to list, show as toast
        state = NotificationState(
          items: [notification, ...state.items],
          toasts: [...state.toasts, notification],
        );
        // Auto-dismiss toast after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _dismissToast(notification.id);
          }
        });
      }
    });
  }

  void _dismissToast(String id) {
    state = NotificationState(
      items: state.items,
      toasts: state.toasts.where((t) => t.id != id).toList(),
    );
  }

  Future<void> _loadUnread() async {
    try {
      final res = await _api.get('/notifications/unread');
      final list = (res.data as List<dynamic>)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
      state = NotificationState(items: list);
    } catch (_) {}
  }

  /// Mark a notification as read locally + backend.
  Future<void> markRead(String id) async {
    try {
      await _api.put('/notifications/$id/read');
    } catch (_) {}
    state = NotificationState(
      items: state.items
          .map((n) => n.id == id ? n.copyWith(read: true) : n)
          .toList(),
      toasts: state.toasts.where((t) => t.id != id).toList(),
    );
  }

  /// Mark all as read.
  Future<void> markAllRead() async {
    try {
      await _api.put('/notifications/read-all');
    } catch (_) {}
    state = NotificationState(
      items: state.items.map((n) => n.copyWith(read: true)).toList(),
      toasts: [],
    );
  }

  /// Dismiss a toast without marking read.
  void dismissToast(String id) {
    _dismissToast(id);
  }

  /// Dismiss all toasts.
  void dismissAllToasts() {
    state = NotificationState(items: state.items);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
  final api = ref.watch(apiClientProvider);
  final ws = ref.watch(webSocketServiceProvider);
  return NotificationNotifier(api, ws);
});

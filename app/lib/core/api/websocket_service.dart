import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/config.dart';

/// Connects to the backend `/events` namespace and exposes a stream of
/// decoded `{event, data}` messages, with automatic reconnection.
class WebSocketService {
  WebSocketService({required this.url});
  final String url;

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _controller;
  Timer? _reconnectTimer;
  bool _disposed = false;

  /// Stream of decoded server events: `{'event': '...', 'data': ...}`.
  Stream<Map<String, dynamic>> get events {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    return _controller!.stream;
  }

  void connect() {
    _controller ??= StreamController<Map<String, dynamic>>.broadcast();
    _doConnect();
  }

  void _doConnect() {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    final sub = _channel!.stream.listen(
      (message) {
        try {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          _controller?.add(decoded);
        } catch (_) {
          // ignore malformed frames
        }
      },
      onDone: _scheduleReconnect,
      onError: (_) => _scheduleReconnect(),
    );
    // keep subscription alive; channel owns lifecycle
    sub;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
  }

  void send(String event, dynamic data) {
    _channel?.sink.add(jsonEncode({'event': event, 'data': data}));
  }

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final svc = WebSocketService(url: AppConfig.wsUrl);
  svc.connect();
  ref.onDispose(svc.dispose);
  return svc;
});
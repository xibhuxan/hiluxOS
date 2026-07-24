/// Runtime configuration. Defaults point to localhost; override at build time:
///   flutter run --dart-define=APP_API_URL=http://192.168.1.10:3000 \
///                --dart-define=APP_WS_URL=ws://192.168.1.10:3000/events
class AppConfig {
  AppConfig._();

  static const String apiUrl =
      String.fromEnvironment('APP_API_URL', defaultValue: 'http://localhost:3000');
  static const String wsUrl =
      String.fromEnvironment('APP_WS_URL', defaultValue: 'ws://localhost:3000/events');

  /// REST base path (the backend serves everything under /api).
  static String restBase = '$apiUrl/api';
}
/// Mirrors the backend Notification model.
class AppNotification {
  final String id;
  final String type; // 'info' | 'success' | 'warning' | 'error'
  final String title;
  final String? message;
  final Map<String, dynamic>? action;
  final bool read;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.message,
    this.action,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      message: json['message'] as String?,
      action: json['action'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      action: action,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}

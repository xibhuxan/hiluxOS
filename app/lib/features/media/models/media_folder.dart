/// A user-configured library folder (see GET /api/media/folders).
class MediaFolder {
  final String id;
  /// Absolute path as configured on the backend.
  final String path;
  /// Display name: the folder's basename.
  final String label;
  /// Whether the path currently exists on disk. False → the rail shows a
  /// warning marker ("ruta no disponible") and the scanner skips it.
  final bool exists;

  const MediaFolder({
    required this.id,
    required this.path,
    required this.label,
    this.exists = true,
  });

  factory MediaFolder.fromJson(Map<String, dynamic> json) => MediaFolder(
        id: json['id'] as String,
        path: json['path'] as String,
        label: json['label'] as String? ?? '',
        exists: json['exists'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'path': path, 'label': label, 'exists': exists};
}

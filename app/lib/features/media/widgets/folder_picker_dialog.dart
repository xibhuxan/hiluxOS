import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/colors.dart';

/// A subdirectory entry as served by GET /media/folders/browse.
class FolderEntry {
  final String name;
  final String path;
  const FolderEntry({required this.name, required this.path});

  factory FolderEntry.fromJson(Map<String, dynamic> j) =>
      FolderEntry(name: j['name'] as String, path: j['path'] as String);
}

/// One level of the filesystem as served by GET /media/folders/browse.
class FolderBrowse {
  final String path;
  final String? parent;
  final String home;
  final bool readable;
  final List<FolderEntry> dirs;
  const FolderBrowse({
    required this.path,
    required this.parent,
    required this.home,
    required this.readable,
    required this.dirs,
  });

  factory FolderBrowse.fromJson(Map<String, dynamic> j) => FolderBrowse(
    path: j['path'] as String,
    parent: j['parent'] as String?,
    home: j['home'] as String,
    readable: (j['readable'] as bool?) ?? true,
    dirs: (j['dirs'] as List<dynamic>? ?? [])
        .map((e) => FolderEntry.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Injects the browse call so widget tests can fake the filesystem.
/// The default hits the backend endpoint (one level per request).
final folderBrowseFnProvider =
    Provider<Future<FolderBrowse> Function(String? path)>((ref) {
      final api = ref.watch(apiClientProvider);
      return (path) async {
        final res = await api.get(
          '/media/folders/browse',
          query: path == null ? null : {'path': path},
        );
        return FolderBrowse.fromJson(res.data as Map<String, dynamic>);
      };
    });

/// System folder picker for adding a library root: navigates the real
/// filesystem (subdirectories only) instead of asking the user to type an
/// absolute path. Pure taps — no text field, so the on-screen keyboard
/// never gets in the way. Pops with the selected absolute path, or null.
class FolderPickerDialog extends ConsumerStatefulWidget {
  const FolderPickerDialog({super.key});

  @override
  ConsumerState<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends ConsumerState<FolderPickerDialog> {
  FolderBrowse? _current;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load(null); // start at the filesystem root
  }

  Future<void> _load(String? path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref.read(folderBrowseFnProvider)(path);
      if (!mounted) return;
      setState(() {
        _current = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo leer esta carpeta';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = _current;
    return AlertDialog(
      title: const Text('Añadir carpeta'),
      content: SizedBox(
        width: 620,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current path with quick navigation chips (up / home).
            Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cur?.path ?? '…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onBackground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(
                  icon: Icons.arrow_upward,
                  label: 'Subir',
                  // Disabled at the filesystem root (parent == null).
                  onTap: cur?.parent == null ? null : () => _load(cur!.parent),
                ),
                const SizedBox(width: 8),
                _chip(
                  icon: Icons.home_outlined,
                  label: 'Inicio',
                  // Only enabled once we know where home is (first browse).
                  onTap: cur == null || cur.home == cur.path
                      ? null
                      : () => _load(cur.home),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(child: _body(cur)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // The current directory becomes the new library root.
          onPressed: cur == null
              ? null
              : () => Navigator.of(context).pop(cur.path),
          child: const Text('Añadir esta carpeta'),
        ),
      ],
    );
  }

  Widget _body(FolderBrowse? cur) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              onPressed: () => _load(cur?.path),
            ),
          ],
        ),
      );
    }
    if (cur == null) return const SizedBox.shrink();
    if (!cur.readable) {
      return const Center(
        child: Text(
          'Sin permisos para leer esta carpeta',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    if (cur.dirs.isEmpty) {
      return const Center(
        child: Text(
          'No hay subcarpetas aquí',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      itemCount: cur.dirs.length,
      itemBuilder: (_, i) {
        final dir = cur.dirs[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.folder, color: AppColors.primary),
          title: Text(dir.name),
          onTap: () => _load(dir.path),
        );
      },
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(
            alpha: enabled ? 0.9 : 0.4,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: enabled ? AppColors.onBackground : AppColors.muted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? AppColors.onBackground : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

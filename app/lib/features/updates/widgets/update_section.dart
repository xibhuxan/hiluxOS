import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../update_provider.dart';

/// Update section card — shown inside the Settings screen.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(updateProvider);
    final notifier = ref.read(updateProvider.notifier);
    final busy = info.status != UpdateStatus.idle &&
        info.status != UpdateStatus.failed &&
        info.status != UpdateStatus.done &&
        info.status != UpdateStatus.rolledBack;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Actualizaciones del sistema',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _infoRow('Versión actual', info.currentVersion),
          if (info.latestVersion != null)
            _infoRow('Última versión', info.latestVersion!),
          if (info.lastAppliedVersion != null)
            _infoRow('Última instalada', info.lastAppliedVersion!),
          const SizedBox(height: 8),
          if (info.status == UpdateStatus.downloading)
            _downloadProgress(info.downloadPercent)
          else if (busy)
            _busyLabel(info.status),
          if (info.lastError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Error: ${info.lastError}',
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (info.releaseNotes != null && info.updateAvailable) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                info.releaseNotes!,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _actionButtons(info, notifier, busy),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _downloadProgress(int percent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Descargando... $percent%',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _busyLabel(UpdateStatus s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(
            _statusLabel(s),
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _actionButtons(UpdateInfo info, UpdateNotifier notifier, bool busy) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : () => notifier.check(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Comprobar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (info.updateAvailable)
          Expanded(
            child: FilledButton.icon(
              onPressed: busy ? null : () => notifier.apply(info.latestVersion!),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Actualizar'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
              ),
            ),
          )
        else if (info.lastAppliedVersion != null)
          Expanded(
            child: TextButton.icon(
              onPressed: busy ? null : () => notifier.rollback(),
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Revertir'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ),
      ],
    );
  }

  String _statusLabel(UpdateStatus s) {
    switch (s) {
      case UpdateStatus.checking:
        return 'Comprobando...';
      case UpdateStatus.downloading:
        return 'Descargando...';
      case UpdateStatus.verifying:
        return 'Verificando firma...';
      case UpdateStatus.applying:
        return 'Instalando...';
      case UpdateStatus.restarting:
        return 'Reiniciando...';
      case UpdateStatus.done:
        return 'Completado';
      case UpdateStatus.failed:
        return 'Fallido';
      case UpdateStatus.rolledBack:
        return 'Revertido';
      default:
        return '';
    }
  }
}
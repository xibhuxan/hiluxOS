import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../features/system_info/system_polling_provider.dart';

/// KDE-style top panel: live clock on the left, system chips in the middle,
/// and Home / Apps actions on the right.
class StatusPanel extends ConsumerWidget {
  const StatusPanel({super.key, required this.onApps, required this.onHome});

  final VoidCallback onApps;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    final poll = ref.watch(systemPollingProvider);
    final res = poll.resources;

    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final date = '${_weekday(now.weekday)} '
        '${now.day.toString().padLeft(2, '0')} ${_month(now.month)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Clock
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.1)),
              Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.1)),
            ],
          ),
          const SizedBox(width: 20),
          // System chips
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Chip(
                  icon: Icons.thermostat_outlined,
                  label: res?.temperature == null
                      ? '--°'
                      : '${res!.temperature!.toStringAsFixed(0)}°',
                  color: res?.temperature == null
                      ? AppColors.muted
                      : AppColors.tempColor(res!.temperature!),
                ),
                _Chip(
                  icon: Icons.memory_outlined,
                  label: res?.memoryUsagePercent == null
                      ? '--%'
                      : '${res!.memoryUsagePercent.toStringAsFixed(0)}%',
                  color: res?.memoryUsagePercent == null
                      ? AppColors.muted
                      : AppColors.usageColor(res!.memoryUsagePercent / 100),
                ),
                _Chip(
                  icon: Icons.timer_outlined,
                  label: res == null ? '--' : _uptime(res.uptimeSeconds),
                  color: AppColors.onBackground,
                ),
              ],
            ),
          ),
          // Actions
          _PanelButton(icon: Icons.home_outlined, onTap: onHome),
          const SizedBox(width: 8),
          _AppsButton(onTap: onApps),
        ],
      ),
    );
  }

  String _uptime(int seconds) {
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  String _weekday(int i) => const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][i - 1];
  String _month(int i) =>
      const ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][i - 1];
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: AppColors.onBackground),
        ),
      ),
    );
  }
}

class _AppsButton extends StatelessWidget {
  const _AppsButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apps, size: 20, color: Color(0xFF0d1117)),
              SizedBox(width: 6),
              Text('Apps',
                  style: TextStyle(
                      color: Color(0xFF0d1117),
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
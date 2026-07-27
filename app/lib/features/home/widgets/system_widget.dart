import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../system_info/controls_provider.dart';
import '../../system_info/health_provider.dart';
import '../../system_info/internet_provider.dart';
import '../../system_info/system_polling_provider.dart';

/// System health card: a compact 2-column stat grid — no progress bars, and
/// each cell scales to fit so it never overflows the card. CPU, RAM, disk,
/// temperature, uptime, plus WiFi, Bluetooth, Internet and Backend status.
class SystemWidget extends ConsumerWidget {
  const SystemWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(systemPollingProvider).resources;
    final net = ref.watch(networkProvider);
    final bt = ref.watch(bluetoothProvider);
    final internet = ref.watch(internetProvider);
    final health = ref.watch(healthProvider);

    final cpuPct = res == null ? null : (res.load1m / res.cpuCount * 100).clamp(0, 999);
    final ramPct = res?.memoryUsagePercent;
    final diskPct = res?.diskUsedPercent?.toDouble();
    final temp = res?.temperature;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text('Sistema',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Stat('CPU', _fmtPct(cpuPct), _pctColor(cpuPct))),
                  _vdiv,
                  Expanded(child: _Stat('Memoria', _fmtPct(ramPct), _pctColor(ramPct))),
                ])),
                _hdiv,
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Stat('Disco', _fmtPct(diskPct), _pctColor(diskPct))),
                  _vdiv,
                  Expanded(child: _Stat('Temp', temp == null ? '--' : '${temp.toStringAsFixed(0)}°',
                      temp == null ? AppColors.muted : AppColors.tempColor(temp))),
                ])),
                _hdiv,
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Stat('Uptime', res == null ? '--' : _uptime(res.uptimeSeconds), AppColors.onBackground)),
                  _vdiv,
                  Expanded(child: _Conn(Icons.wifi, 'WiFi', net.ssid ?? (net.wifiEnabled == true ? 'Sin conexión' : 'Apagado'), net.connected)),
                ])),
                _hdiv,
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Conn(Icons.bluetooth, 'Bluetooth', bt.connected ? 'Conectado' : (bt.powered == true ? 'Activo' : 'Apagado'), bt.connected)),
                  _vdiv,
                  Expanded(child: _Conn(Icons.public, 'Internet', internet.reachable ? 'Conectado' : 'Sin conexión', internet.reachable)),
                ])),
                _hdiv,
                Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Conn(Icons.dns, 'Backend', health.ok ? (health.databaseOk ? 'Online' : 'Sin DB') : 'Offline', health.ok)),
                  _vdiv,
                  const Expanded(child: SizedBox()),
                ])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtPct(num? v) => v == null ? '--' : '${v.toStringAsFixed(0)}%';
  Color _pctColor(num? v) =>
      v == null ? AppColors.muted : AppColors.usageColor((v / 100).clamp(0.0, 1.0));

  String _uptime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  static const Widget _hdiv = Divider(color: AppColors.surfaceVariant, height: 1, thickness: 1);
  static const Widget _vdiv = VerticalDivider(color: AppColors.surfaceVariant, width: 1, thickness: 1);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, height: 1.1)),
          ],
        ),
      ),
    );
  }
}

class _Conn extends StatelessWidget {
  const _Conn(this.icon, this.label, this.value, this.on);
  final IconData icon;
  final String label;
  final String value;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? AppColors.accent : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color, height: 1.1)),
          ],
        ),
      ),
    );
  }
}
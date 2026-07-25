import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../features/system_info/controls_provider.dart';
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
    final temp = res?.temperature;
    final ram = res?.memoryUsagePercent;
    final up = res?.uptimeSeconds;

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
                  icon: Icons.speed_outlined,
                  label: res == null
                      ? '--%'
                      : '${((res.load1m / res.cpuCount) * 100).clamp(0, 999).toStringAsFixed(0)}%',
                  color: res == null
                      ? AppColors.muted
                      : AppColors.usageColor(res.load1m / res.cpuCount),
                ),
                _Chip(
                  icon: Icons.thermostat_outlined,
                  label: temp == null ? '--°' : '${temp.toStringAsFixed(0)}°',
                  color: temp == null ? AppColors.muted : AppColors.tempColor(temp),
                ),
                _Chip(
                  icon: Icons.memory_outlined,
                  label: ram == null ? '--%' : '${ram.toStringAsFixed(0)}%',
                  color: ram == null ? AppColors.muted : AppColors.usageColor(ram / 100),
                ),
                _Chip(
                  icon: Icons.timer_outlined,
                  label: up == null ? '--' : _uptime(up),
                  color: AppColors.onBackground,
                ),
              ],
            ),
          ),
          // Quick controls
          const SizedBox(width: 8),
          const _VolumeControl(),
          const SizedBox(width: 8),
          const _WifiToggle(),
          const SizedBox(width: 8),
          const _BtToggle(),
          const SizedBox(width: 10),
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

/// Inline volume control: mute toggle + slider. Updates the system volume
/// through the backend on drag end.
class _VolumeControl extends ConsumerStatefulWidget {
  const _VolumeControl();
  @override
  ConsumerState<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends ConsumerState<_VolumeControl> {
  double? _drag;
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final audio = ref.watch(audioProvider);
    final muted = audio.muted ?? false;
    final vol = audio.volume == null
        ? 0.0
        : _dragging && _drag != null
            ? _drag!
            : (audio.volume!.clamp(0, 100).toDouble());
    final effective = muted ? 0.0 : vol;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: audio.volume == null ? null : () => ref.read(audioProvider.notifier).toggleMuted(),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                muted || effective == 0 ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                size: 18,
                color: muted ? AppColors.muted : AppColors.onBackground,
              ),
            ),
          ),
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                min: 0,
                max: 100,
                value: effective,
                onChanged: audio.volume == null
                    ? null
                    : (v) {
                        setState(() {
                          _drag = v;
                          _dragging = true;
                        });
                      },
                onChangeEnd: (v) {
                  setState(() => _dragging = false);
                  ref.read(audioProvider.notifier).setVolume(v.round());
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiToggle extends ConsumerWidget {
  const _WifiToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final net = ref.watch(networkProvider);
    final on = net.wifiEnabled ?? false;
    final available = net.wifiEnabled != null;
    return _ToggleChip(
      icon: on ? Icons.wifi : Icons.wifi_off,
      label: on ? (net.ssid ?? 'WiFi') : 'WiFi',
      active: on,
      enabled: available,
      onTap: available ? () => ref.read(networkProvider.notifier).toggle() : null,
    );
  }
}

class _BtToggle extends ConsumerWidget {
  const _BtToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bt = ref.watch(bluetoothProvider);
    final on = bt.powered ?? false;
    final available = bt.powered != null;
    return _ToggleChip(
      icon: on ? Icons.bluetooth : Icons.bluetooth_disabled,
      label: on ? (bt.connected ? 'Conectado' : 'BT') : 'BT',
      active: on,
      enabled: available,
      onTap: available ? () => ref.read(bluetoothProvider.notifier).toggle() : null,
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? AppColors.muted
        : active
            ? AppColors.primary
            : AppColors.onBackground;
    return Material(
      color: active
          ? AppColors.primary.withValues(alpha: 0.16)
          : AppColors.surfaceVariant.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
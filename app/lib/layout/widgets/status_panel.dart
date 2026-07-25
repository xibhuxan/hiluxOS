import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../features/system_info/controls_provider.dart';
import '../../features/system_info/system_polling_provider.dart';

/// KDE-style top panel: volume control on the left, live clock, and
/// Home / Apps actions on the right. System metrics live in the home cards.
class StatusPanel extends ConsumerWidget {
  const StatusPanel({super.key, required this.onApps, required this.onHome});

  final VoidCallback onApps;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);

    final time = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    final date = '${_weekday(now.weekday)} '
        '${now.day.toString().padLeft(2, '0')} ${_month(now.month)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          // Volume (left, wide for finger precision)
          const _VolumeControl(),
          const SizedBox(width: 18),
          // Clock
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(time, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.1)),
              Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 11, height: 1.1)),
            ],
          ),
          const Spacer(),
          // Actions
          _PanelButton(icon: Icons.home_outlined, onTap: onHome),
          const SizedBox(width: 8),
          _AppsButton(onTap: onApps),
        ],
      ),
    );
  }

  String _weekday(int i) => const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'][i - 1];
  String _month(int i) =>
      const ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][i - 1];
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
            width: 180,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
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


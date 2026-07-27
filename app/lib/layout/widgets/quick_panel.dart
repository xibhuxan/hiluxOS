import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../features/system_info/controls_provider.dart';
import '../../features/system_info/quick_panel_provider.dart';

/// Quick Panel overlay: slides down from the top with WiFi/BT toggles,
/// volume/brightness sliders, and status indicators.
class QuickPanel extends ConsumerStatefulWidget {
  const QuickPanel({super.key});

  @override
  ConsumerState<QuickPanel> createState() => QuickPanelState();
}

class QuickPanelState extends ConsumerState<QuickPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void open() => _controller.forward();
  void close() => _controller.reverse();
  bool get isOpen => _controller.isCompleted;
  bool get isAnimating => _controller.isAnimating;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slide,
      child: FadeTransition(
        opacity: _fade,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              border: const Border(
                bottom: BorderSide(color: AppColors.glassBorder),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SafeArea(
              bottom: false,
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.muted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Toggles row: WiFi, Bluetooth
                  Row(
                    children: [
                      Expanded(child: _ToggleTile(
                        icon: Icons.wifi,
                        label: 'WiFi',
                        provider: networkProvider,
                        onChanged: (ref) => ref.read(networkProvider.notifier).toggle(),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ToggleTile(
                        icon: Icons.bluetooth,
                        label: 'Bluetooth',
                        provider: bluetoothProvider,
                        onChanged: (ref) => ref.read(bluetoothProvider.notifier).toggle(),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Volume slider
                  _SliderTile(
                    icon: Icons.volume_up_outlined,
                    label: 'Volumen',
                    provider: audioProvider,
                    getValue: _audioValue,
                    onChanged: _audioChanged,
                  ),
                  const SizedBox(height: 12),
                  // Brightness slider
                  _SliderTile(
                    icon: Icons.brightness_medium,
                    label: 'Brillo',
                    provider: brightnessProvider,
                    getValue: _brightnessValue,
                    onChanged: _brightnessChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Helpers for slider tiles ----

double _audioValue(WidgetRef ref) {
  final s = ref.watch(audioProvider);
  return (s.volume ?? 0).toDouble();
}

double _brightnessValue(WidgetRef ref) {
  final s = ref.watch(brightnessProvider);
  return s.value.toDouble();
}

void _audioChanged(WidgetRef ref, double v) {
  ref.read(audioProvider.notifier).setVolume(v.round());
}

void _brightnessChanged(WidgetRef ref, double v) {
  ref.read(brightnessProvider.notifier).setBrightness(v.round());
}

// ---- Toggle tile (WiFi / Bluetooth) ----

class _ToggleTile extends ConsumerWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.provider,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final dynamic provider;
  final void Function(WidgetRef ref) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final bool enabled;
    if (state is NetworkState) {
      enabled = state.wifiEnabled ?? false;
    } else if (state is BluetoothState) {
      enabled = state.powered ?? false;
    } else {
      enabled = false;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: enabled ? AppColors.primary : AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.onBackground : AppColors.muted)),
          ),
          GestureDetector(
            onTap: () => onChanged(ref),
            child: Container(
              width: 44,
              height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: enabled ? AppColors.primary : AppColors.surfaceVariant,
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Slider tile (Volume / Brightness) ----

class _SliderTile extends ConsumerWidget {
  const _SliderTile({
    required this.icon,
    required this.label,
    required this.provider,
    required this.getValue,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final dynamic provider;
  final double Function(WidgetRef ref) getValue;
  final void Function(WidgetRef ref, double value) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = getValue(ref);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.onBackground),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.surfaceVariant,
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: 0,
                max: 100,
                divisions: 100,
                value: value.clamp(0, 100),
                onChanged: (v) => onChanged(ref, v),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text('${value.round()}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import 'btmedia_provider.dart';

/// The Bluetooth media screen: a touch-first A2DP/AVRCP now-playing view.
///
/// Layout (top → bottom):
///  - Connected-device chip.
///  - Now-playing: album-art placeholder + title/artist/album.
///  - Progress bar with position / duration.
///  - Large transport controls (prev / play-pause / next).
///  - Volume slider.
///
/// Distinct empty states: "Bluetooth no disponible" (no adapter) vs
/// "Sin dispositivo" (adapter but no phone connected), each with Reintentar.
class BtMediaScreen extends ConsumerWidget {
  const BtMediaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(btMediaProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.backendReachable) {
      return _empty(
        icon: Icons.cloud_off_outlined,
        title: 'Backend no disponible',
        subtitle: 'No se pudo conectar con el servidor',
      );
    }
    if (!state.available) {
      return _empty(
        icon: Icons.bluetooth_disabled,
        title: 'Bluetooth no disponible',
        subtitle: 'No se detectó un adaptador Bluetooth',
      );
    }
    if (!state.connected) {
      return _empty(
        icon: Icons.bluetooth_searching,
        title: 'Sin dispositivo',
        subtitle: 'Empareja un teléfono para reproducir música',
      );
    }

    return Column(
      children: [
        _DeviceChip(state: state),
        const SizedBox(height: 12),
        Expanded(child: _NowPlaying(state: state)),
        const SizedBox(height: 8),
        _Progress(state: state),
        const SizedBox(height: 4),
        _Controls(state: state),
        const SizedBox(height: 4),
        _Volume(state: state),
      ],
    );
  }

  Widget _empty({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Consumer(
            builder: (context, ref, _) => OutlinedButton.icon(
              onPressed: () => ref.read(btMediaProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Connected-device chip (phone name + bluetooth icon).
class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.state});
  final BtMediaState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bluetooth_connected, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                state.deviceName ?? 'Dispositivo',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


/// Now-playing: album-art placeholder + title / artist / album.
class _NowPlaying extends StatelessWidget {
  const _NowPlaying({required this.state});
  final BtMediaState state;

  @override
  Widget build(BuildContext context) {
    final track = state.track;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.glassBorder),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.25),
                AppColors.purple.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: const Icon(Icons.music_note, size: 72, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        Text(
          track?.title ?? 'Sin pista',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onBackground),
        ),
        const SizedBox(height: 4),
        Text(
          track?.artist ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          track?.album ?? '',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Progress bar with position / duration.
class _Progress extends StatelessWidget {
  const _Progress({required this.state});
  final BtMediaState state;

  String _fmt(int sec) {
    final s = sec < 0 ? 0 : sec;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final track = state.track;
    final dur = track?.durationSec ?? 0;
    final pos = track?.positionSec ?? 0;
    final fraction = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surfaceVariant,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.2),
            ),
            // Read-only progress (seek over AVRCP is not in scope).
            child: Slider(value: fraction, onChanged: (_) {}),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(pos), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                Text(_fmt(dur), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Large touch transport controls: previous / play-pause / next.
class _Controls extends ConsumerWidget {
  const _Controls({required this.state});
  final BtMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(btMediaProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          iconSize: 44,
          onPressed: notifier.previous,
          icon: const Icon(Icons.skip_previous, color: AppColors.onBackground),
          tooltip: 'Anterior',
        ),
        const SizedBox(width: 18),
        Material(
          color: AppColors.primary,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: notifier.togglePlayPause,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(
                state.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 46,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        IconButton(
          iconSize: 44,
          onPressed: notifier.next,
          icon: const Icon(Icons.skip_next, color: AppColors.onBackground),
          tooltip: 'Siguiente',
        ),
      ],
    );
  }
}

/// Absolute volume slider.
class _Volume extends ConsumerWidget {
  const _Volume({required this.state});
  final BtMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(btMediaProvider.notifier);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Row(
        children: [
          const Icon(Icons.volume_down, color: AppColors.muted),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.surfaceVariant,
                thumbColor: AppColors.accent,
                overlayColor: AppColors.accent.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: state.volume.clamp(0.0, 1.0),
                onChanged: notifier.setVolume,
              ),
            ),
          ),
          const Icon(Icons.volume_up, color: AppColors.muted),
        ],
      ),
    );
  }
}


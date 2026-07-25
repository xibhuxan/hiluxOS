import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../radio/radio_provider.dart';
import '../../radio/widgets/spectrum_visualizer.dart';

/// Mini now-playing plasmoid. Shows the current station + a compact visualizer
/// when something is playing, or an idle hint otherwise. Tap opens the radio.
class NowPlayingWidget extends ConsumerWidget {
  const NowPlayingWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radio = ref.watch(radioProvider);
    final current = radio.current;

    return GlassCard(
      accentGlow: radio.isPlaying,
      onTap: () => context.go('/radio'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                radio.isPlaying ? Icons.graphic_eq : Icons.radio,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text('Radio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          if (current != null) ...[
            Text(current.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            if (current.country != null)
              Text(current.country!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: ClipRect(child: FittedBox(fit: BoxFit.fitWidth, child: SpectrumVisualizer(active: radio.isPlaying, barCount: 28))),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Nada en reproducción.\nPulsa para buscar emisoras.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4)),
            ),
        ],
      ),
    );
  }
}
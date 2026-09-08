import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import 'equalizer_provider.dart';

/// The equalizer screen: a beautiful, touch-first 8-band graphic EQ.
///
/// Layout (top → bottom):
///  - Header: master enable switch, reset and "save preset" actions.
///  - A horizontally-scrolling row of preset chips.
///  - The band sliders with a smoothed frequency-response curve painted behind
///    them (the curve follows the gains live).
///  - A footer with the stereo balance slider and the loudness toggle.
class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(equalizerProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.available) {
      return _unavailable();
    }

    return Column(
      children: [
        _Header(state: state),
        const SizedBox(height: 8),
        _PresetRow(state: state),
        const SizedBox(height: 4),
        Expanded(child: _BandPanel(state: state)),
        const SizedBox(height: 8),
        _Footer(state: state),
      ],
    );
  }

  Widget _unavailable() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.volume_off_outlined,
              size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          const Text('Audio no disponible',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 2),
          const Text('No se detectó un servidor de audio (PipeWire)',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Header: master enable + reset + save-preset.
class _Header extends ConsumerWidget {
  const _Header({required this.state});
  final EqualizerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(equalizerProvider.notifier);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: state.enabled
                ? AppColors.primary.withValues(alpha: 0.18)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.enabled ? AppColors.primary : AppColors.glassBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.equalizer,
                  size: 18, color: state.enabled ? AppColors.primary : AppColors.muted),
              const SizedBox(width: 8),
              Text(
                state.enabled ? 'Activado' : 'Desactivado',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: state.enabled ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 6),
              Switch(
                value: state.enabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => notifier.setEnabled(v),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Restablecer (plano)',
          icon: const Icon(Icons.restart_alt, color: AppColors.muted),
          onPressed: () => notifier.reset(),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant,
            foregroundColor: AppColors.onBackground,
          ),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Guardar'),
          onPressed: () => _saveDialog(context, notifier),
        ),
      ],
    );
  }

  void _saveDialog(BuildContext context, EqualizerNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Guardar preset'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Nombre del preset'),
          onSubmitted: (_) => _save(ctx, notifier, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => _save(ctx, notifier, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext ctx, EqualizerNotifier notifier, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    notifier.savePreset(trimmed);
    Navigator.of(ctx).pop();
  }
}

/// Horizontally-scrolling preset chips; the active one is highlighted.
class _PresetRow extends ConsumerWidget {
  const _PresetRow({required this.state});
  final EqualizerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(equalizerProvider.notifier);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.presets.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final p = state.presets[i];
          final active = state.activePreset == p.name;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => notifier.applyPreset(p.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: active ? AppColors.accentGradient : null,
                  color: active ? null : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? Colors.transparent : AppColors.glassBorder,
                  ),
                ),
                child: Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.onBackground,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
/// The 8 vertical band sliders over a live frequency-response curve.
class _BandPanel extends ConsumerWidget {
  const _BandPanel({required this.state});
  final EqualizerState state;

  static String _fmtFreq(double f) =>
      f >= 1000 ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k' : '${f.round()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(equalizerProvider.notifier);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: CustomPaint(
          painter: _ResponseCurvePainter(
            gains: state.gains,
            minGain: state.minGain,
            maxGain: state.maxGain,
            enabled: state.enabled,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < state.bands.length; i++)
                  Expanded(
                    child: _BandSlider(
                      index: i,
                      freq: state.bands[i].freq,
                      gain: state.bands[i].gain,
                      min: state.minGain,
                      max: state.maxGain,
                      enabled: state.enabled,
                      onChanged: (v) => notifier.setBandLive(i, v),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single vertical band: gain value, slider, and frequency label.
class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.index,
    required this.freq,
    required this.gain,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final int index;
  final double freq;
  final double gain;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primary : AppColors.muted;
    return Column(
      children: [
        Text(
          gain == 0 ? '0' : (gain > 0 ? '+${gain.toStringAsFixed(0)}' : gain.toStringAsFixed(0)),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: gain == 0 ? AppColors.muted : color,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: color,
                inactiveTrackColor: AppColors.surfaceVariant,
                thumbColor: enabled ? Colors.white : AppColors.muted,
              ),
              child: Slider(
                min: min,
                max: max,
                divisions: (max - min).round(),
                value: gain.clamp(min, max),
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _BandPanel._fmtFreq(freq),
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }
}


/// Footer: stereo balance slider + loudness toggle.
class _Footer extends ConsumerWidget {
  const _Footer({required this.state});
  final EqualizerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(equalizerProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          // Balance.
          const Icon(Icons.surround_sound, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: Text(
              state.balance == 0
                  ? 'Centro'
                  : state.balance < 0
                      ? 'Izq ${(state.balance.abs() * 100).round()}'
                      : 'Der ${(state.balance * 100).round()}',
              style: const TextStyle(fontSize: 12, color: AppColors.onBackground),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: AppColors.purple,
                inactiveTrackColor: AppColors.surfaceVariant,
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: -1,
                max: 1,
                divisions: 20,
                value: state.balance.clamp(-1.0, 1.0),
                onChanged: state.enabled ? (v) => notifier.setBalance(v) : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Loudness.
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: state.enabled ? () => notifier.setLoudness(!state.loudness) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: state.loudness
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.loudness ? AppColors.accent : AppColors.glassBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign,
                      size: 16, color: state.loudness ? AppColors.accent : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    'Loudness',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: state.loudness ? AppColors.accent : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Paints a smoothed frequency-response curve (Catmull-Rom → Bézier) through
/// the band gains, with a soft gradient fill. The curve is purely decorative —
/// the sliders are the control — but makes the EQ feel alive.
class _ResponseCurvePainter extends CustomPainter {
  _ResponseCurvePainter({
    required this.gains,
    required this.minGain,
    required this.maxGain,
    required this.enabled,
  });

  final List<double> gains;
  final double minGain;
  final double maxGain;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (gains.isEmpty) return;

    final color = enabled ? AppColors.primary : AppColors.muted;
    double yFor(double gain) {
      final t = (gain - minGain) / (maxGain - minGain); // 0..1, low→high
      return size.height * (1 - t);
    }

    // Sample points, one per band, spread evenly across the width.
    final n = gains.length;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(size.width * (i + 0.5) / n, yFor(gains[i])),
    ];

    // Zero-gain reference line.
    final zeroY = yFor(0);
    final zeroPaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroPaint);

    // Smoothed path through the points (Catmull-Rom spline → cubic Bézier).
    final path = Path()..moveTo(0, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i == 0 ? i : i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[i + 2 < pts.length ? i + 2 : i + 1];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6);
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    path.lineTo(size.width, pts.last.dy);

    // Filled area under the curve.
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // The curve stroke itself.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_ResponseCurvePainter old) =>
      old.gains != gains || old.enabled != enabled;
}


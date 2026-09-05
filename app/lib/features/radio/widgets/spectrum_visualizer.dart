import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../spectrum_provider.dart';
import '../visualizer_style.dart';
import 'spectrum_painters.dart';

/// Audio spectrum visualizer with switchable rendering styles.
///
/// Architecture (the fix for the "regulero" / choppy updates):
/// - A single [Ticker] runs the winamp-style peak-hold + exponential decay
///   smoothing over the latest backend bands (48 floats @ 30 fps over the
///   `/events` WebSocket) — or pseudo data when no real data is available.
/// - The smoothed result is pushed into a [SpectrumFrame] (a [ChangeNotifier])
///   which the active painter listens to via `repaint: frame`. Bar motion
///   therefore repaints ONLY the canvas — zero widget-tree rebuilds per
///   frame, zero `setState`, zero layout work (the pattern recommended by
///   the FFT/visualizer literature and used by audio_visualizer/fftea).
/// - The style picker (the toolbar button) swaps painters.
class SpectrumVisualizer extends ConsumerStatefulWidget {
  const SpectrumVisualizer({
    super.key,
    this.barCount = 48,
    this.active = true,
    this.showStyleButton = false,
  });

  final int barCount;
  final bool active;

  /// When true, renders a small style-picker button in the visualizer's
  /// top-right corner.
  final bool showStyleButton;

  @override
  ConsumerState<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends ConsumerState<SpectrumVisualizer>
    with TickerProviderStateMixin {
  late final List<double> _bars;
  late final List<double> _peaks; // peak-hold values (winamp-style)
  late final SpectrumFrame _frame;
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _phase = 0;
  final _rng = math.Random();

  /// Debug instrumentation: last provider band list identity + counters to
  /// measure how many times per second REAL backend data arrives.
  List<double>? _lastRealBands;
  int _upsCount = 0;
  double _upsWindow = 0;

  /// Debug: per-band content tracking — when did each band's raw value
  /// actually CHANGE (content, not message arrival).
  List<double>? _prevRawValues;
  late final List<double> _bandChangeAt;
  int _contentChanges = 0;
  double _clock = 0;

  /// Smoothed energy envelope (0..1) that tracks the [active] flag so the
  /// transition between playing and idle is gradual rather than instant.
  double _energy = 0;

  /// Smoothed dim factor (1 = full, ~0.38 = idle) applied to painter colors.
  double _dim = 0.4;

  @override
  void initState() {
    super.initState();
    _bars = List.filled(widget.barCount, 0.02);
    _peaks = List.filled(widget.barCount, 0.02);
    _bandChangeAt = List.filled(widget.barCount, 0);
    _frame = SpectrumFrame(_bars, _peaks);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    // Media mounts/unmounts this widget when switching now-playing modes,
    // so the Ticker must be properly stopped and disposed (leaking it
    // trips TickerProviderStateMixin's assert when the tree finalizes).
    _ticker.stop();
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    // Real delta time in seconds (clamped to avoid huge jumps after stalls).
    final dt = (_lastElapsed == Duration.zero
            ? 0.016
            : (elapsed - _lastElapsed).inMicroseconds / 1e6)
        .clamp(0.001, 0.05);
    _lastElapsed = elapsed;
    _phase += dt * 15;

    // Target energy: full when active (playing), near-zero otherwise.
    final target = widget.active ? 1.0 : 0.05;
    _energy += (target - _energy) * (dt * 6).clamp(0.0, 1.0);
    _dim = 0.35 + _energy * 0.65;

    // Check for real spectrum data from the backend.
    final spectrum = ref.read(spectrumProvider);
    final realBands = spectrum.bands;
    final isStale = spectrum.stale;
    _frame.stale = isStale;

    // --- Debug instrumentation: measure REAL updates-per-second ----------
    // Message rate (any new band list arriving) AND content rate (frames
    // whose numbers actually changed) — plus per-band change age.
    _clock += dt;
    if (!identical(realBands, _lastRealBands)) {
      _lastRealBands = realBands;
      _upsCount++;
      if (realBands != null && _prevRawValues != null) {
        for (var i = 0;
            i < realBands.length && i < _prevRawValues!.length;
            i++) {
          if ((realBands[i] - _prevRawValues![i]).abs() > 0.001) {
            _bandChangeAt[i] = _clock;
            _contentChanges++;
          }
        }
      }
      if (realBands != null) {
        _prevRawValues = List<double>.from(realBands);
      }
    }
    _upsWindow += dt;
    if (_upsWindow >= 0.5) {
      _frame.realUps = _upsCount / _upsWindow;
      _frame.contentUps = _contentChanges / _upsWindow;
      _upsCount = 0;
      _contentChanges = 0;
      _upsWindow = 0;
    }
    // Expose per-band change age (ms since its raw value last changed).
    final ages = _frame.bandAgeMs;
    final rawCount = realBands?.length ?? 0;
    for (var i = 0; i < ages.length; i++) {
      if (i < rawCount) {
        ages[i] = ((_clock - _bandChangeAt[i]) * 1000).clamp(0, 9999);
      } else {
        ages[i] = -1; // no real data for this band
      }
    }

    // Winamp-style peak-hold + exponential decay, fed by temporally-smoothed
    // (EMA) bands from the backend — so frontend smoothing stays subtle:
    // no double-smoothing lag, just graceful motion.
    // Attack: rise with a fast time constant (~45 ms).
    // Decay: fall with a slower time constant (~150 ms).
    final attack = (1 - math.exp(-dt / 0.045)).clamp(0.0, 1.0);
    final decay = (1 - math.exp(-dt / 0.15)).clamp(0.0, 1.0);

    for (var i = 0; i < _bars.length; i++) {
      double targetBar;
      if (realBands != null && i < realBands.length) {
        if (isStale) {
          // Buffer underrun: blend the decaying backend value with a gentle
          // pseudo wave so the visualizer stays alive but calm (not frozen,
          // not full-energy). The blend weight shifts toward pseudo as the
          // backend value fades to zero.
          final real = realBands[i].clamp(0.02, 1.0);
          final pseudo = _pseudoAmplitude(i) * 0.4;
          final w = real.clamp(0.0, 1.0);
          targetBar = real * w + pseudo * (1 - w);
        } else {
          targetBar = realBands[i].clamp(0.02, 1.0);
        }
      } else {
        targetBar = _pseudoAmplitude(i);
      }

      // Asymmetric EMA: quick rise, graceful fall — the classic
      // audio-visualizer feel without frame-to-frame jitter.
      final k = targetBar > _peaks[i] ? attack : decay;
      _peaks[i] = _peaks[i] * (1 - k) + targetBar * k;
      _bars[i] = _peaks[i].clamp(0.02, 1.0);
    }

    // --- Sub-band energies for the new styles (VU, bubbles, pulse...) ------
    // Smoothed EMA so needles/blobs glide instead of twitching.
    _frame.raw = realBands; // untouched backend values for debug/waterfall
    final third = math.max(1, _bars.length ~/ 3);
    double avg(int from, int to) {
      var sum = 0.0;
      for (var i = from; i < to && i < _bars.length; i++) {
        sum += _bars[i];
      }
      return to > from ? sum / (to - from) : 0.0;
    }

    final bassT = avg(0, third);
    final midT = avg(third, third * 2);
    final trebleT = avg(third * 2, _bars.length);
    final energyT = (bassT + midT + trebleT) / 3;
    final kE = (1 - math.exp(-dt / 0.08)).clamp(0.0, 1.0);
    _frame.bass += (bassT - _frame.bass) * kE;
    _frame.mid += (midT - _frame.mid) * kE;
    _frame.treble += (trebleT - _frame.treble) * kE;
    _frame.energy += (energyT - _frame.energy) * kE;

    // Push the smoothed frame to the painters — repaint ONLY the canvas,
    // never the widget tree.
    _frame.update(_bars, _peaks, _phase);
  }

  /// Compute a pseudo-reactive amplitude for bar [i] (used when no real
  /// spectrum data is available). This produces a lively "dancing bars"
  /// effect that settles to a calm idle when playback stops.
  double _pseudoAmplitude(int i) {
    // Frequency-domain feel: each bar gets a different base frequency so
    // the pattern looks like a spectrum, not a single wave.
    final freq = 0.25 + (i / _bars.length) * 1.8;
    final w1 = (math.sin(_phase * freq + i * 0.3) + 1) / 2;
    final w2 = (math.sin(_phase * freq * 0.5 + i * 0.7) + 1) / 2;
    final impulse = _rng.nextDouble() < 0.08 ? _rng.nextDouble() * 0.5 : 0.0;

    // Center-emphasis so the middle bars (where energy concentrates in
    // most music) are taller, tapering at the edges like a real spectrum.
    final centerFactor = 1 - ((i - _bars.length / 2).abs() / (_bars.length / 2));
    return (w1 * 0.5 + w2 * 0.25 + impulse) * _energy * (0.4 + centerFactor * 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final style = ref.watch(visualizerStyleProvider);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: buildPainter(style.style, _frame, _dim),
            ),
          ),
        ),
        if (widget.showStyleButton)
          Positioned(
            top: 0,
            right: 0,
            child: _styleMenuButton(style),
          ),
      ],
    );
  }

  /// Popup menu with every style plus the "Aleatorio" (random) entry that
  /// keeps switching styles every 12 s, like a music player shuffling
  /// through its visualizer presets.
  Widget _styleMenuButton(VisualizerStyleState style) {
    final notifier = ref.read(visualizerStyleProvider.notifier);
    return PopupMenuButton<String>(
      tooltip: 'Visualizador',
      icon: Icon(style.style.icon, color: AppColors.muted, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: AppColors.surfaceVariant,
      onSelected: (v) {
        if (v == 'random') {
          notifier.setRandom();
        } else {
          notifier.setStyle(VisualizerStyle.values.byName(v));
        }
      },
      itemBuilder: (_) => [
        for (final s in VisualizerStyle.values)
          PopupMenuItem(
            value: s.name,
            child: _menuRow(s.icon, s.label,
                selected: s == style.style && !style.random),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'random',
          child: _menuRow(Icons.shuffle, 'Aleatorio', selected: style.random),
        ),
      ],
    );
  }

  Widget _menuRow(IconData icon, String label, {required bool selected}) {
    return Row(children: [
      Icon(icon, size: 18, color: selected ? AppColors.primary : AppColors.muted),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: selected ? AppColors.primary : AppColors.onBackground)),
    ]);
  }
}

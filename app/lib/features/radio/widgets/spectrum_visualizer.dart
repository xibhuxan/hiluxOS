import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../core/theme/colors.dart';

/// A simple animated bar visualizer. It runs a lightweight idle animation
/// when idle and a fuller, amplitude-style animation when [active]. We use a
/// self-driven animation rather than raw audio samples so the visualizer stays
/// platform-independent (Linux desktop dev doesn't expose FFT samples).
class SpectrumVisualizer extends StatefulWidget {
  const SpectrumVisualizer({
    super.key,
    this.barCount = 32,
    this.active = true,
  });

  final int barCount;
  final bool active;

  @override
  State<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends State<SpectrumVisualizer>
    with TickerProviderStateMixin {
  late final List<double> _bars;
  late final Ticker _ticker;
  double _phase = 0;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _bars = List.filled(widget.barCount, 0.0);
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    _phase += 0.2;
    setState(() {
      for (var i = 0; i < _bars.length; i++) {
        final centerFactor =
            1 - ((i - _bars.length / 2).abs() / _bars.length);
        final idle = (sin(_phase + i * 0.4) + 1) / 2 * 0.25;
        final noise = _rng.nextDouble() * 0.1;
        final amp = widget.active ? centerFactor * 0.6 : 0.0;
        _bars[i] = (idle + amp + noise).clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _bars.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: FractionallySizedBox(
                  heightFactor: 0.1 + _bars[i] * 0.9,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [AppColors.primary, AppColors.accent],
                      ),
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
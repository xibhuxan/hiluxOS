import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available spectrum visualizer styles, inspired by the classic winamp /
/// audio_visualizer set: bars, LED blocks, smooth line, mirrored bars,
/// layered waves and a radial circle.
enum VisualizerStyle {
  bars,
  blocks,
  line,
  mirror,
  wave,
  circle,
  vu,
  waterfall,
  starfield,
  bubbles,
  pulse,
  ring,
  reactive,
  kaleidoscope,
  debug
}

extension VisualizerStyleX on VisualizerStyle {
  /// Human-readable (Spanish) label shown in the style picker menu.
  String get label {
    switch (this) {
      case VisualizerStyle.bars:
        return 'Barras';
      case VisualizerStyle.blocks:
        return 'Bloques';
      case VisualizerStyle.line:
        return 'Línea';
      case VisualizerStyle.mirror:
        return 'Espejo';
      case VisualizerStyle.wave:
        return 'Ondas';
      case VisualizerStyle.circle:
        return 'Círculo';
      case VisualizerStyle.vu:
        return 'Vúmetro';
      case VisualizerStyle.waterfall:
        return 'Cascada';
      case VisualizerStyle.starfield:
        return 'Túnel';
      case VisualizerStyle.bubbles:
        return 'Burbujas';
      case VisualizerStyle.pulse:
        return 'Pulso';
      case VisualizerStyle.ring:
        return 'Anillo';
      case VisualizerStyle.reactive:
        return 'Reactivo';
      case VisualizerStyle.kaleidoscope:
        return 'Caleidoscopio';
      case VisualizerStyle.debug:
        return 'Debug';
    }
  }

  /// Icon shown next to the label in the style picker menu.
  IconData get icon {
    switch (this) {
      case VisualizerStyle.bars:
        return Icons.equalizer;
      case VisualizerStyle.blocks:
        return Icons.grid_on;
      case VisualizerStyle.line:
        return Icons.show_chart;
      case VisualizerStyle.mirror:
        return Icons.flip;
      case VisualizerStyle.wave:
        return Icons.waves;
      case VisualizerStyle.circle:
        return Icons.data_usage;
      case VisualizerStyle.vu:
        return Icons.speed;
      case VisualizerStyle.waterfall:
        return Icons.water_drop;
      case VisualizerStyle.starfield:
        return Icons.rocket_launch;
      case VisualizerStyle.bubbles:
        return Icons.bubble_chart;
      case VisualizerStyle.pulse:
        return Icons.monitor_heart;
      case VisualizerStyle.ring:
        return Icons.circle_outlined;
      case VisualizerStyle.reactive:
        return Icons.palette;
      case VisualizerStyle.kaleidoscope:
        return Icons.auto_awesome;
      case VisualizerStyle.debug:
        return Icons.bug_report;
    }
  }
}

/// State for the visualizer style picker: the currently selected style plus
/// whether "random" mode is on (a timer keeps switching styles over time).
class VisualizerStyleState {
  const VisualizerStyleState({this.style = VisualizerStyle.bars, this.random = false});

  final VisualizerStyle style;
  final bool random;

  VisualizerStyleState copyWith({VisualizerStyle? style, bool? random}) =>
      VisualizerStyleState(style: style ?? this.style, random: random ?? this.random);
}

/// Holds the selected [VisualizerStyle] and the random-rotation timer.
///
/// In random mode the style changes every [randomInterval] to a different
/// one (never repeating the current style back to back), like a music player
/// shuffling through its visualizer presets.
class VisualizerStyleNotifier extends StateNotifier<VisualizerStyleState> {
  VisualizerStyleNotifier({this.randomInterval = const Duration(seconds: 12), math.Random? rng})
      : _rng = rng ?? math.Random(),
        super(const VisualizerStyleState());

  /// How often the style changes while in random mode.
  final Duration randomInterval;
  final math.Random _rng;
  Timer? _randomTimer;

  /// Selects a concrete style and disables random mode.
  void setStyle(VisualizerStyle style) {
    if (state.style == style && !state.random) return;
    _stopTimer();
    state = VisualizerStyleState(style: style, random: false);
  }

  /// Enables random mode: picks a first style immediately and keeps
  /// rotating every [randomInterval].
  void setRandom() {
    if (state.random) return;
    state = state.copyWith(random: true);
    _pickRandomStyle();
    _randomTimer ??= Timer.periodic(randomInterval, (_) => _pickRandomStyle());
  }

  /// Picks a random style different from the current one.
  void _pickRandomStyle() {
    final others = VisualizerStyle.values.where((s) => s != state.style).toList();
    state = state.copyWith(style: others[_rng.nextInt(others.length)]);
  }

  void _stopTimer() {
    _randomTimer?.cancel();
    _randomTimer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}

final visualizerStyleProvider =
    StateNotifierProvider<VisualizerStyleNotifier, VisualizerStyleState>(
  (ref) => VisualizerStyleNotifier(),
);

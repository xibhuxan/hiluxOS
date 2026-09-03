// ignore_for_file: avoid_relative_lib_imports
import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import '../lib/features/radio/visualizer_style.dart';

void main() {
  group('VisualizerStyleNotifier', () {
    test('setStyle picks a concrete style and disables random mode', () {
      final n = VisualizerStyleNotifier();
      addTearDown(n.dispose);

      n.setRandom();
      expect(n.state.random, isTrue);

      n.setStyle(VisualizerStyle.circle);
      expect(n.state.style, VisualizerStyle.circle);
      expect(n.state.random, isFalse,
          reason: 'selecting a concrete style must disable random rotation');
    });

    test('setRandom picks a different style immediately and keeps rotating',
        () async {
      // Deterministic rng stub: always returns 0 → always picks the first
      // "other" style.
      final n = VisualizerStyleNotifier(
        randomInterval: const Duration(milliseconds: 10),
        rng: _FixedRng(0),
      );
      addTearDown(n.dispose);

      final before = n.state.style; // default = bars
      n.setRandom();
      expect(n.state.random, isTrue);
      expect(n.state.style, isNot(before),
          reason: 'setRandom must switch away from the current style');

      // After the rotation interval it must have switched again (and never
      // back to back to the same style, since _pickRandomStyle excludes it).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final styles = <VisualizerStyle>{};
      var polls = 0;
      while (polls++ < 20) {
        styles.add(n.state.style);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(styles.length, greaterThan(1),
          reason: 'random mode must rotate styles over time');
    });

    test('dispose cancels the rotation timer without throwing', () async {
      final n = VisualizerStyleNotifier(
        randomInterval: const Duration(milliseconds: 5),
        rng: _FixedRng(0),
      );
      n.setRandom();
      n.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });

  group('VisualizerStyleX', () {
    test('every style has a label and an icon', () {
      for (final s in VisualizerStyle.values) {
        expect(s.label, isNotEmpty);
        expect(s.icon, isNotNull);
      }
    });
  });
}

/// A [Random] stub that always returns [v] — makes the "different from
/// current" logic deterministic in tests.
class _FixedRng implements Random {
  _FixedRng(this.v);
  final int v;

  @override
  int nextInt(int max) => v % max;

  @override
  bool nextBool() => v % 2 == 0;

  @override
  double nextDouble() => v / 10.0;
}

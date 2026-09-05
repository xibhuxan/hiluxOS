// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/core/widgets/progress_bar.dart';
import '../lib/features/splash/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders the logo, title and subtitle', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    // Let the first frame settle (enter/glow/progress controllers start).
    await tester.pump();

    expect(find.text('hiluxOS'), findsOneWidget);
    expect(find.text('Infotainment System'), findsOneWidget);
    // The logo image asset is referenced; in tests it errors silently but the
    // ClipRRect/Image widget is still in the tree.
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('SplashScreen shows a progress bar that advances over time', (
    tester,
  ) async {
    // Give the splash enough vertical space — the logo + glow stack is ~460px.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    // The animated progress bar exists in the tree.
    expect(find.byType(AnimatedProgressBar), findsOneWidget);

    // After pumping some time, the splash is still showing (the 4-second
    // animation has not completed yet).
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('hiluxOS'), findsOneWidget);
  });

  testWidgets('splash logo degrades gracefully when the asset fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();

    // The splash logo must have an errorBuilder so a missing/stale asset
    // shows the brand icon instead of Flutter's red error box.
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.errorBuilder, isNotNull);

    // Invoking it yields the fallback: mount it and find the brand icon.
    final ctx = tester.state(find.byType(Image)).context;
    final fallback = image.errorBuilder!(ctx, Exception('asset'), null);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: fallback)));
    expect(find.byIcon(Icons.directions_car_filled), findsOneWidget);
  });
}

// ignore_for_file: avoid_relative_lib_imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import '../lib/layout/app_shell.dart';
import '../lib/layout/fullscreen_host.dart';

/// Mounts the AppShell with a body that can enter full-screen mode. The
/// router wraps it like the real app (ShellRoute) — but a plain home with
/// the shell is enough for the overlay test.
Widget _harness({void Function(AppShellState shell)? onReady}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(
          routeLocation: state.uri.path,
          child: Builder(
            builder: (context) {
              return _Probe(onShell: onReady);
            },
          ),
        ),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

/// Body widget that grabs its AppShellState and exposes a button to enter
/// full-screen with some identifiable content.
class _Probe extends StatelessWidget {
  const _Probe({this.onShell});
  final void Function(AppShellState shell)? onShell;

  @override
  Widget build(BuildContext context) {
    final shell = context.findAncestorStateOfType<AppShellState>();
    if (shell != null && onShell != null) onShell!(shell);
    return Center(
      child: Column(
        children: [
          const Text('BODY'),
          FilledButton(
            onPressed: () => shell?.enterFullscreen(
              (context, exit) => const Center(child: Text('FULLSCREEN-CONTENT')),
            ),
            child: const Text('ENTER'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('enterFullscreen overlays content; tap anywhere exits', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // The body is visible and the overlay is not.
    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('FULLSCREEN-CONTENT'), findsNothing);

    // Enter full-screen.
    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The overlay content is on screen. (Widget finders can't prove the
    // body is covered — taps below do: every point hits the overlay.)
    expect(find.text('FULLSCREEN-CONTENT'), findsOneWidget);

    // Tapping anywhere (the center) exits.
    await tester.tapAt(const Offset(200, 200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('BODY'), findsOneWidget);
    expect(find.text('FULLSCREEN-CONTENT'), findsNothing);
  });

  testWidgets('the fullscreen overlay covers the status panel too', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ENTER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FULLSCREEN-CONTENT'), findsOneWidget);

    // Tapping the status-bar region exits — the overlay sits above it
    // (the whole screen went black), so the tap can't reach the panel.
    await tester.tapAt(const Offset(400, 40));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('FULLSCREEN-CONTENT'), findsNothing);
  });

  testWidgets('FullscreenHost tap is what drives exit, not route pops', (tester) async {
    // FullscreenHost in isolation inside a plain Stack with a body behind:
    // a tap anywhere must fire onExit exactly once.
    var exited = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const Center(child: Text('BEHIND')),
            FullscreenHost(
              onExit: () => exited++,
              builder: (context, exit) => const Center(child: Text('OVERLAY')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('OVERLAY'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(exited, 1);
  });
}

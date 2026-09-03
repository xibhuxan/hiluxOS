import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:virtual_keypad/virtual_keypad.dart';
import 'core/theme/app_theme.dart';
import 'layout/navigation_router.dart';

void main() {
  // Register the built-in keyboard layouts (en, es, fr, …) so the on-screen
  // VirtualKeypad can render. Required once before runApp on the embedded
  // target where no system IME exists.
  initializeKeyboardLayouts();
  runApp(const ProviderScope(child: HiluxOSApp()));
}

/// Scroll behavior that enables drag-to-scroll from touch pointers on desktop
/// (Linux/Wayland). Flutter's default [MaterialScrollBehavior] only honors
/// touch dragging on mobile platforms; on desktop it relies on the mouse wheel.
/// The in-vehicle display is touch-only and has no scroll wheel, so we add
/// [PointerDeviceKind.touch] (and stylus/trackpad inertial) to the drag set
/// everywhere in the app.
class _TouchScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}

class HiluxOSApp extends ConsumerWidget {
  const HiluxOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'hiluxOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      scrollBehavior: _TouchScrollBehavior(),
      routerConfig: router,
    );
  }
}
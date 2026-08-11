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

class HiluxOSApp extends ConsumerWidget {
  const HiluxOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'hiluxOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
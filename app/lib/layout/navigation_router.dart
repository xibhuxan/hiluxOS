import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/home/home_screen.dart';
import '../features/radio/radio_screen.dart';
import '../features/system_info/system_info_screen.dart';
import '../features/settings/settings_screen.dart';
import 'app_shell.dart';

/// Fade + slight slide-up transition used by the shell routes.
Page<void> _fadeSlidePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (_, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _fadeSlidePage(key: state.pageKey, child: const HomeScreen()),
          ),
          GoRoute(
            path: '/radio',
            pageBuilder: (_, state) => _fadeSlidePage(key: state.pageKey, child: const RadioScreen()),
          ),
          GoRoute(
            path: '/system',
            pageBuilder: (_, state) => _fadeSlidePage(key: state.pageKey, child: const SystemInfoScreen()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (_, state) => _fadeSlidePage(key: state.pageKey, child: const SettingsScreen()),
          ),
        ],
      ),
    ],
  );
});
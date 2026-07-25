import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';
import 'widgets/app_drawer_grid.dart';
import 'widgets/status_panel.dart';

/// Main layout: a KDE-style top status panel, the routed body, and an app
/// drawer (cajón) opened from the panel's Apps button.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(84),
        child: SafeArea(
          bottom: false,
          child: StatusPanel(
            onApps: () => _scaffoldKey.currentState?.openEndDrawer(),
            onHome: () => context.go('/'),
          ),
        ),
      ),
      endDrawer: const AppDrawerGrid(),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
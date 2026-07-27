import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';
import 'widgets/app_drawer_grid.dart';
import 'widgets/status_panel.dart';
import 'widgets/quick_panel.dart';

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
  final _quickPanelKey = GlobalKey<QuickPanelState>();

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
            onQuickPanel: () {
              final state = _quickPanelKey.currentState;
              if (state == null) return;
              if (state.isOpen || state.isAnimating) {
                state.close();
              } else {
                state.open();
              }
            },
          ),
        ),
      ),
      endDrawer: const AppDrawerGrid(),
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: widget.child,
              ),
            ),
          ),
          // Dismiss layer: taps outside the panel close it
          _QuickPanelDismiss(key: _quickPanelKey),
          // Quick Panel overlay
          QuickPanel(key: _quickPanelKey),
        ],
      ),
    );
  }
}

/// Transparent overlay that closes the Quick Panel when tapped.
/// Only captures events when the panel is open.
class _QuickPanelDismiss extends StatelessWidget {
  const _QuickPanelDismiss({super.key});

  @override
  Widget build(BuildContext context) {
    final qp = context.findAncestorStateOfType<_AppShellState>()
        ?._quickPanelKey.currentState;
    final visible = qp != null && (qp.isOpen || qp.isAnimating);
    return IgnorePointer(
      ignoring: !visible,
      child: GestureDetector(
        onTap: () => qp?.close(),
        child: Container(color: visible ? Colors.black.withValues(alpha: 0.2) : Colors.transparent),
      ),
    );
  }
}
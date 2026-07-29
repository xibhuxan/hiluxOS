import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';
import '../features/notifications/widgets/notification_toast.dart';
import '../features/notifications/widgets/notification_panel.dart';
import 'widgets/app_drawer_grid.dart';
import 'widgets/status_panel.dart';
import 'widgets/quick_panel.dart';

/// Main layout: a KDE-style top status panel, the routed body, and an app
/// drawer (cajón) opened from the panel's Apps button.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => AppShellState();
}

/// Public state so dismiss overlays can access the panel keys.
class AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _quickPanelKey = GlobalKey<QuickPanelState>();
  final _notificationPanelKey = GlobalKey<NotificationPanelState>();
  bool _notifOpen = false;
  bool _quickOpen = false;

  void _onNotifChanged(bool open) {
    if (_notifOpen != open) setState(() => _notifOpen = open);
  }

  void _onQuickChanged(bool open) {
    if (_quickOpen != open) setState(() => _quickOpen = open);
  }

  void toggleQuickPanel() {
    final state = _quickPanelKey.currentState;
    if (state == null) return;
    if (state.isOpen || state.isAnimating) {
      state.close();
    } else {
      state.open();
    }
  }

  void toggleNotificationPanel() {
    _notificationPanelKey.currentState?.toggle();
  }

  void closeNotificationPanel() {
    _notificationPanelKey.currentState?.close();
  }

  void closeQuickPanel() {
    _quickPanelKey.currentState?.close();
  }

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
            onQuickPanel: toggleQuickPanel,
            onNotifications: toggleNotificationPanel,
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
          // Dismiss layer for quick panel (below quick panel so panel is tappable)
          if (_quickOpen)
            _QuickPanelDismiss(
              shell: this,
              onTap: closeQuickPanel,
            ),
          // Quick Panel overlay (above its dismiss layer)
          QuickPanel(
            key: _quickPanelKey,
            onOpenChanged: _onQuickChanged,
          ),
          // Dismiss layer for notification panel (below notification panel)
          if (_notifOpen)
            _NotificationDismiss(
              shell: this,
              onTap: closeNotificationPanel,
            ),
          // Notification panel overlay (above its dismiss layer)
          NotificationPanel(
            key: _notificationPanelKey,
            onOpenChanged: _onNotifChanged,
          ),
          // Notification toasts (top of the screen)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: NotificationToast(),
          ),
        ],
      ),
    );
  }
}

/// Transparent overlay that closes the Quick Panel when tapped.
class _QuickPanelDismiss extends StatelessWidget {
  const _QuickPanelDismiss({required this.shell, required this.onTap});
  final AppShellState shell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.2),
      ),
    );
  }
}

/// Transparent overlay that closes the Notification Panel when tapped.
class _NotificationDismiss extends StatelessWidget {
  const _NotificationDismiss({required this.shell, required this.onTap});
  final AppShellState shell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.2),
      ),
    );
  }
}

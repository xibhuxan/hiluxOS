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
          // Notification panel overlay (slides from top, above content)
          NotificationPanel(key: _notificationPanelKey),
          // Quick Panel overlay
          QuickPanel(key: _quickPanelKey),
          // Dismiss layer for notification panel
          _NotificationDismiss(shell: this),
          // Dismiss layer for quick panel
          _QuickPanelDismiss(shell: this),
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
  const _QuickPanelDismiss({required this.shell});
  final AppShellState shell;

  @override
  Widget build(BuildContext context) {
    final qp = shell._quickPanelKey.currentState;
    final visible = qp != null && (qp.isOpen || qp.isAnimating);
    return IgnorePointer(
      ignoring: !visible,
      child: GestureDetector(
        onTap: shell.closeQuickPanel,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: visible ? Colors.black.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
    );
  }
}

/// Transparent overlay that closes the Notification Panel when tapped.
class _NotificationDismiss extends StatelessWidget {
  const _NotificationDismiss({required this.shell});
  final AppShellState shell;

  @override
  Widget build(BuildContext context) {
    final np = shell._notificationPanelKey.currentState;
    final visible = np != null && (np.isOpen || np.isAnimating);
    return IgnorePointer(
      ignoring: !visible,
      child: GestureDetector(
        onTap: shell.closeNotificationPanel,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: visible ? Colors.black.withValues(alpha: 0.2) : Colors.transparent,
        ),
      ),
    );
  }
}

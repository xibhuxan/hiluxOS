import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:virtual_keypad/virtual_keypad.dart';
import '../core/theme/colors.dart';
import '../features/notifications/widgets/notification_toast.dart';
import '../features/notifications/widgets/notification_panel.dart';
import 'fullscreen_host.dart';
import 'widgets/app_drawer_grid.dart';
import 'widgets/status_panel.dart';
import 'widgets/quick_panel.dart';

/// Main layout: a KDE-style top status panel, the routed body, and an app
/// drawer (cajón) opened from the panel's Apps button.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, required this.routeLocation});
  final Widget child;
  final String routeLocation;

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
  bool _keyboardVisible = false;

  /// Active full-screen content (tap-to-exit now-playing), or null.
  FullscreenBuilder? _fullscreenBuilder;

  /// Backdrop for the active full-screen content (black for album art,
  /// the panel surface tone for the spectrum — see FullscreenHost).
  Color _fullscreenBackground = Colors.black;

  /// Show [builder]'s content full-screen (tap anywhere exits). Available to
  /// any screen inside the shell via its ancestor AppShellState. [background]
  /// picks the backdrop (album art: pure black; spectrum: surface tone so the
  /// painters' translucent colors don't read darker than in their Card).
  void enterFullscreen(
    FullscreenBuilder builder, {
    Color background = Colors.black,
  }) {
    setState(() {
      _fullscreenBuilder = builder;
      _fullscreenBackground = background;
    });
  }

  void _exitFullscreen() {
    if (_fullscreenBuilder == null) return;
    setState(() => _fullscreenBuilder = null);
  }

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
    return Stack(
      children: [
        Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.background,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(84),
            child: SafeArea(
              bottom: false,
              child: StatusPanel(
                routeLocation: widget.routeLocation,
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
              // Main content. When the on-screen keyboard is visible we reserve
              // space at the bottom so the focused field stays visible above it.
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.backgroundGradient,
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.only(
                        bottom: _keyboardVisible ? 280 : 0,
                      ),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
              // Dismiss layer for quick panel (below quick panel so panel is tappable)
              if (_quickOpen)
                _QuickPanelDismiss(shell: this, onTap: closeQuickPanel),
              // Quick Panel overlay (above its dismiss layer)
              QuickPanel(key: _quickPanelKey, onOpenChanged: _onQuickChanged),
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
              // On-screen virtual keyboard, pinned to the bottom. Standalone mode
              // attaches to any focused TextField/TextFormField in the subtree, so
              // dialogs (TaskDialog, WiFi password, BT PIN) get a keyboard for free.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VirtualKeypad(
                  standalone: true,
                  hideWhenUnfocused: true,
                  onVisibilityChanged: (v) {
                    if (_keyboardVisible != v) {
                      setState(() => _keyboardVisible = v);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        // Tap-to-exit full-screen now-playing overlay (Media album art /
        // spectrum, Radio spectrum). OUTSIDE the Scaffold so it covers the
        // status panel too — the whole screen goes black. It never coexists
        // with the keyboard (no text fields in full-screen content).
        if (_fullscreenBuilder != null)
          FullscreenHost(
            builder: _fullscreenBuilder!,
            onExit: _exitFullscreen,
            background: _fullscreenBackground,
          ),
      ],
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

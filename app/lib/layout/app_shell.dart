import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/colors.dart';

/// Main layout: a body (the current route) plus a bottom navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    _Tab('/', Icons.home_outlined, Icons.home, 'Home'),
    _Tab('/radio', Icons.radio_outlined, Icons.radio, 'Radio'),
    _Tab('/system', Icons.memory_outlined, Icons.memory, 'System'),
    _Tab('/settings', Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  int _indexFromLocation(String location) {
    final idx = _tabs.indexWhere((t) => location.startsWith(t.path));
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFromLocation(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon, color: AppColors.primary),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _Tab(this.path, this.icon, this.selectedIcon, this.label);
}
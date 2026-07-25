import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/app_tile.dart';
import '../../core/widgets/staggered_entrance.dart';

/// The app drawer (cajón): a responsive grid of launcher tiles.
class AppDrawerGrid extends ConsumerWidget {
  const AppDrawerGrid({super.key});

  static const _apps = <_AppDef>[
    _AppDef(path: '/radio', name: 'Radio', icon: Icons.radio, color: AppColors.primary, enabled: true),
    _AppDef(path: '/system', name: 'System', icon: Icons.memory, color: AppColors.accent, enabled: true),
    _AppDef(path: '/settings', name: 'Settings', icon: Icons.settings, color: AppColors.purple, enabled: true),
    _AppDef(path: '/media', name: 'Media', icon: Icons.library_music_outlined, color: AppColors.warning, enabled: false),
    _AppDef(path: '/bluetooth', name: 'Bluetooth', icon: Icons.bluetooth, color: AppColors.primary, enabled: false),
    _AppDef(path: '/obd', name: 'OBD-II', icon: Icons.directions_car_outlined, color: AppColors.accent, enabled: false),
    _AppDef(path: '/camera', name: 'Camera', icon: Icons.videocam_outlined, color: AppColors.danger, enabled: false),
    _AppDef(path: '/voice', name: 'Voice', icon: Icons.mic_outlined, color: AppColors.purple, enabled: false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AppColors.background,
      width: MediaQuery.of(context).size.width * 0.62,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(0), bottomLeft: Radius.circular(0)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aplicaciones',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Text('Todas tus apps en un sitio',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: _apps.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, i) {
                    final a = _apps[i];
                    return StaggeredEntrance(
                      index: i,
                      child: AppTile(
                        icon: a.icon,
                        name: a.name,
                        color: a.color,
                        enabled: a.enabled,
                        onTap: () {
                          Navigator.of(context).maybePop();
                          context.go(a.path);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDef {
  final String path;
  final String name;
  final IconData icon;
  final Color color;
  final bool enabled;
  const _AppDef({
    required this.path,
    required this.name,
    required this.icon,
    required this.color,
    required this.enabled,
  });
}
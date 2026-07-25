import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../../features/system_info/system_polling_provider.dart';
import 'widgets/now_playing_widget.dart';
import 'widgets/system_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider);
    final greeting = _greeting(now.hour);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Greeting
        StaggeredEntrance(
          index: 0,
          child: Text(greeting,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 4),
        StaggeredEntrance(
          index: 1,
          child: const Text('Esto es lo que está pasando',
              style: TextStyle(color: AppColors.muted, fontSize: 14)),
        ),
        const SizedBox(height: 20),

        // Plasmoid grid fills the remaining space (no scroll).
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 720;
              return GridView.count(
                crossAxisCount: wide ? 2 : 1,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: wide ? 1.05 : 1.7,
                children: [
                  StaggeredEntrance(index: 2, child: const SystemWidget()),
                  StaggeredEntrance(index: 3, child: const NowPlayingWidget()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _greeting(int hour) {
    if (hour < 6) return 'Buenas noches';
    if (hour < 13) return 'Buenos días';
    if (hour < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }
}
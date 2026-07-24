import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../system_info/system_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(systemProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sys = ref.watch(systemProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('hiluxOS')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.3,
        children: [
          _DashboardCard(
            icon: Icons.radio,
            title: 'Radio',
            value: sys.resources == null ? '—' : 'Online streams',
            color: AppColors.primary,
            onTap: () => context.go('/radio'),
          ),
          _DashboardCard(
            icon: Icons.memory,
            title: 'System',
            value: sys.resources == null
                ? '—'
                : '${sys.resources!.memoryUsagePercent.toStringAsFixed(0)}% RAM',
            color: AppColors.accent,
            onTap: () => context.go('/system'),
          ),
          _DashboardCard(
            icon: Icons.thermostat,
            title: 'Temp',
            value: sys.resources?.temperature == null
                ? 'n/a'
                : '${sys.resources!.temperature!.toStringAsFixed(0)} °C',
            color: AppColors.warning,
            onTap: () => context.go('/system'),
          ),
          _DashboardCard(
            icon: Icons.settings,
            title: 'Settings',
            value: 'Configure',
            color: const Color(0xFFbc8cff),
            onTap: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              const Spacer(),
              Text(title, style: const TextStyle(fontSize: 16, color: AppColors.onBackground)),
              if (value.isNotEmpty)
                Text(value, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
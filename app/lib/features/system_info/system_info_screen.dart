import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'system_provider.dart';
import '../../core/theme/colors.dart';

class SystemInfoScreen extends ConsumerStatefulWidget {
  const SystemInfoScreen({super.key});

  @override
  ConsumerState<SystemInfoScreen> createState() => _SystemInfoScreenState();
}

class _SystemInfoScreenState extends ConsumerState<SystemInfoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(systemProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(systemProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(systemProvider.notifier).load(),
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? _ErrorView(state.error!, ref.read(systemProvider.notifier).load)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: Text('Sistema',
                            style:
                                TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                      ),
                      if (state.info != null) _infoCard('Identity', _infoRows(state.info!)),
                      const SizedBox(height: 12),
                      if (state.resources != null)
                        _infoCard('Resources', _resourceRows(state.resources!)),
                    ],
                  ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 16)),
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
      );

  List<Widget> _infoRows(SystemInfo i) => [
        _row('Hostname', i.hostname),
        _row('Platform', i.platform),
        _row('Arch', i.arch),
        _row('CPUs', '${i.cpus}'),
        _row('Total RAM', '${i.totalMemoryMb.toStringAsFixed(0)} MB'),
        _row('Uptime', '${i.uptimeSeconds}s'),
      ];

  List<Widget> _resourceRows(SystemResources r) => [
        _row('Memory usage', '${r.memoryUsagePercent.toStringAsFixed(1)}%'),
        _row('Free RAM', '${r.freeMemoryMb.toStringAsFixed(0)} MB'),
        _row('Temperature', r.temperature == null ? 'n/a' : '${r.temperature!.toStringAsFixed(1)} °C'),
        _row('Uptime', '${r.uptimeSeconds}s'),
      ];

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted)),
            Text(value),
          ],
        ),
      );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView(this.error, this.onRetry);
  final String error;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      );
}
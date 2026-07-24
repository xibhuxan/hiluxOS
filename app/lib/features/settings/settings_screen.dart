import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import '../../core/theme/colors.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).load();
    });
  }

  bool _isBool(String v) => v == 'true' || v == 'false';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider);
    final keys = state.values.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: state.loading && state.values.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: keys.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.surfaceVariant),
              itemBuilder: (context, i) {
                final key = keys[i];
                final value = state.values[key]!;
                if (_isBool(value)) {
                  return SwitchListTile(
                    title: Text(_pretty(key)),
                    value: value == 'true',
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).update(key, v.toString()),
                  );
                }
                final n = int.tryParse(value);
                if (n != null && (key == 'brightness' || key == 'volume')) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_pretty(key), style: const TextStyle(color: AppColors.onBackground)),
                      Slider(
                        min: 0,
                        max: 100,
                        divisions: 100,
                        value: n.toDouble().clamp(0, 100),
                        label: '$n',
                        onChanged: (v) =>
                            ref.read(settingsProvider.notifier).update(key, v.round().toString()),
                      ),
                    ],
                  );
                }
                return ListTile(
                  title: Text(_pretty(key)),
                  trailing: Text(value, style: const TextStyle(color: AppColors.muted)),
                );
              },
            ),
    );
  }

  String _pretty(String key) => key.replaceAll('_', ' ').replaceFirst(
        key[0],
        key[0].toUpperCase(),
      );
}
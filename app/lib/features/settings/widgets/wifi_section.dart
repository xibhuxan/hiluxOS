import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../system_info/controls_provider.dart';
import 'network_dialogs.dart';

/// Wi-Fi settings card: toggle radio, show the active connection, scan for
/// nearby networks and connect (with a password dialog for secure networks).
class WifiSection extends ConsumerStatefulWidget {
  const WifiSection({super.key});

  @override
  ConsumerState<WifiSection> createState() => _WifiSectionState();
}

class _WifiSectionState extends ConsumerState<WifiSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final net = ref.read(networkProvider);
      if (net.wifiEnabled == true && net.networks.isEmpty) {
        ref.read(networkProvider.notifier).scan();
      }
    });
  }

  Future<void> _connectTo(WifiNetwork net) async {
    if (net.secure) {
      final pwd = await showDialog<String>(
        context: context,
        builder: (_) => WifiPasswordDialog(ssid: net.ssid, secure: true),
      );
      if (pwd == null || !mounted) return;
      await ref.read(networkProvider.notifier).connect(net.ssid, pwd);
    } else {
      await ref.read(networkProvider.notifier).connect(net.ssid, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = ref.watch(networkProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Text('Wi-Fi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (net.wifiEnabled == true)
                Text(net.connected ? (net.ssid ?? 'Conectada') : 'Desconectada',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              Switch(
                value: net.wifiEnabled ?? false,
                onChanged: (v) => ref.read(networkProvider.notifier).toggle(),
              ),
            ],
          ),
          if (net.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(net.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          if (net.wifiEnabled == true) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: net.scanning
                      ? null
                      : () => ref.read(networkProvider.notifier).scan(),
                  icon: net.scanning
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh, size: 18),
                  label: Text(net.scanning ? 'Buscando…' : 'Buscar redes'),
                ),
                const Spacer(),
                if (net.connected)
                  TextButton(
                    onPressed: () => ref.read(networkProvider.notifier).disconnect(),
                    child: const Text('Desconectar', style: TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (net.networks.isEmpty && !net.scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hay redes. Pulsa "Buscar redes".',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              ...net.networks.map((n) => _NetworkTile(
                    network: n,
                    active: n.ssid == net.ssid,
                    onTap: () => _connectTo(n),
                    onForget: n.ssid == net.ssid
                        ? null
                        : () => ref.read(networkProvider.notifier).forget(n.ssid),
                  )),
          ],
        ],
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.network,
    required this.active,
    required this.onTap,
    this.onForget,
  });
  final WifiNetwork network;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(network.secure ? Icons.wifi_lock : Icons.wifi,
          color: active ? AppColors.accent : AppColors.muted, size: 20),
      title: Text(network.ssid,
          style: TextStyle(
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? AppColors.accent : AppColors.onBackground)),
      subtitle: Text('Señal ${network.signal}%', style: const TextStyle(fontSize: 11)),
      trailing: active
          ? const Text('Conectada', style: TextStyle(color: AppColors.accent, fontSize: 12))
          : (onForget != null
              ? IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                  onPressed: onForget,
                  tooltip: 'Olvidar',
                )
              : const Icon(Icons.chevron_right, color: AppColors.muted)),
      onTap: active ? null : onTap,
    );
  }
}
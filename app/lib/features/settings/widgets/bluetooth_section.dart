import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../system_info/controls_provider.dart';
import 'network_dialogs.dart';

/// Bluetooth settings card: toggle power, scan for devices, pair (with an
/// optional PIN dialog), connect/disconnect and remove paired devices.
class BluetoothSection extends ConsumerStatefulWidget {
  const BluetoothSection({super.key});

  @override
  ConsumerState<BluetoothSection> createState() => _BluetoothSectionState();
}

class _BluetoothSectionState extends ConsumerState<BluetoothSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bt = ref.read(bluetoothProvider);
      if (bt.powered == true && bt.devices.isEmpty) {
        ref.read(bluetoothProvider.notifier).scan();
      }
    });
  }

  Future<void> _pair(BluetoothDevice dev) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => BtPinDialog(name: dev.name),
    );
    if (!mounted) return;
    await ref.read(bluetoothProvider.notifier).pair(dev.mac, pin);
  }

  @override
  Widget build(BuildContext context) {
    final bt = ref.watch(bluetoothProvider);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bluetooth, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Text('Bluetooth',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (bt.powered == true)
                Text(bt.connected ? 'Conectado' : 'Encendido',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              Switch(
                value: bt.powered ?? false,
                onChanged: (v) => ref.read(bluetoothProvider.notifier).toggle(),
              ),
            ],
          ),
          if (bt.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(bt.error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
          if (bt.powered == true) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: bt.scanning ? null : () => ref.read(bluetoothProvider.notifier).scan(),
              icon: bt.scanning
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 18),
              label: Text(bt.scanning ? 'Buscando…' : 'Buscar dispositivos'),
            ),
            const SizedBox(height: 8),
            if (bt.devices.isEmpty && !bt.scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No hay dispositivos. Pulsa "Buscar dispositivos".',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              ...bt.devices.map((d) => _DeviceTile(
                    device: d,
                    onPair: () => _pair(d),
                    onConnect: () => ref.read(bluetoothProvider.notifier).connect(d.mac),
                    onDisconnect: () => ref.read(bluetoothProvider.notifier).disconnect(d.mac),
                    onRemove: () => ref.read(bluetoothProvider.notifier).remove(d.mac),
                  )),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onPair,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRemove,
  });
  final BluetoothDevice device;
  final VoidCallback onPair;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final status = device.connected
        ? 'Conectado'
        : device.paired
            ? 'Emparejado'
            : 'Disponible';
    final statusColor = device.connected
        ? AppColors.accent
        : device.paired
            ? AppColors.primary
            : AppColors.muted;
    return ListTile(
      dense: true,
      leading: Icon(Icons.bluetooth, color: statusColor, size: 20),
      title: Text(device.name,
          style: const TextStyle(color: AppColors.onBackground, fontWeight: FontWeight.w400)),
      subtitle: Text(device.mac, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
          PopupMenuButton<_BtAction>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.muted),
            onSelected: (a) {
              switch (a) {
                case _BtAction.pair:
                  onPair();
                  break;
                case _BtAction.connect:
                  onConnect();
                  break;
                case _BtAction.disconnect:
                  onDisconnect();
                  break;
                case _BtAction.remove:
                  onRemove();
                  break;
              }
            },
            itemBuilder: (_) => [
              if (!device.paired)
                const PopupMenuItem(value: _BtAction.pair, child: Text('Emparejar')),
              if (device.paired && !device.connected)
                const PopupMenuItem(value: _BtAction.connect, child: Text('Conectar')),
              if (device.connected)
                const PopupMenuItem(value: _BtAction.disconnect, child: Text('Desconectar')),
              if (device.paired)
                const PopupMenuItem(value: _BtAction.remove, child: Text('Olvidar')),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BtAction { pair, connect, disconnect, remove }
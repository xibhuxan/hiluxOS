import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../../radio/radio_provider.dart';
import '../../system_info/controls_provider.dart';
import '../../system_info/health_provider.dart';

/// The single most important thing happening right now. Never metrics.
class EstadoActualCard extends ConsumerWidget {
  const EstadoActualCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radio = ref.watch(radioProvider);
    final bt = ref.watch(bluetoothProvider);
    final health = ref.watch(healthProvider);

    final state = _resolve(radio, bt, health);

    return GlassCard(
      accentGlow: state.tone == _Tone.active,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(state.icon, color: state.color, size: 22),
              const SizedBox(width: 8),
              const Text('Estado actual',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const Spacer(),
          Text(state.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: state.color)),
          if (state.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(state.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  _Resolved _resolve(RadioState radio, BluetoothState bt, HealthState health) {
    if (!health.ok) {
      return _Resolved(Icons.cloud_off, 'Backend desconectado',
          subtitle: 'Revisa el servicio', tone: _Tone.warning, color: AppColors.danger);
    }
    if (!health.databaseOk) {
      return _Resolved(Icons.storage, 'PostgreSQL desconectado',
          subtitle: 'Base de datos', tone: _Tone.warning, color: AppColors.danger);
    }
    if (radio.current != null && radio.isPlaying) {
      return _Resolved(Icons.graphic_eq, 'Reproduciendo',
          subtitle: radio.current!.name, tone: _Tone.active, color: AppColors.primary);
    }
    if (bt.connected) {
      return _Resolved(Icons.bluetooth_connected, 'Bluetooth conectado',
          subtitle: null, tone: _Tone.active, color: AppColors.primary);
    }
    return _Resolved(Icons.check_circle, 'Todo funciona correctamente',
        subtitle: null, tone: _Tone.ok, color: AppColors.accent);
  }
}

enum _Tone { ok, active, warning }

class _Resolved {
  final IconData icon;
  final String text;
  final String? subtitle;
  final _Tone tone;
  final Color color;
  _Resolved(this.icon, this.text, {this.subtitle, required this.tone, required this.color});
}
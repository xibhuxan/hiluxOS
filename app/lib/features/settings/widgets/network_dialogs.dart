import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Dialog to enter a Wi-Fi password (or confirm an open-network connect).
/// Uses a standard TextField with `TextInputType.visiblePassword` so the
/// on-screen VirtualKeypad (standalone mode) shows a QWERTY layout.
class WifiPasswordDialog extends StatefulWidget {
  const WifiPasswordDialog({super.key, required this.ssid, this.secure = true});
  final String ssid;
  final bool secure;

  @override
  State<WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<WifiPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Conectar a "${widget.ssid}"'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.secure)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Red abierta — sin contraseña.', style: TextStyle(color: AppColors.muted)),
            )
          else
            TextField(
              controller: _controller,
              obscureText: _obscure,
              keyboardType: TextInputType.visiblePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppColors.muted),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.isEmpty ? null : _controller.text),
          child: const Text('Conectar'),
        ),
      ],
    );
  }
}

/// Dialog to enter a Bluetooth pairing PIN (numeric). Uses a numeric
/// TextInputType so the on-screen keypad shows a numpad layout.
class BtPinDialog extends StatefulWidget {
  const BtPinDialog({super.key, required this.name});
  final String name;

  @override
  State<BtPinDialog> createState() => _BtPinDialogState();
}

class _BtPinDialogState extends State<BtPinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Emparejar "${widget.name}"'),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(),
        maxLength: 16,
        decoration: const InputDecoration(
          labelText: 'PIN',
          hintText: '0000',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.isEmpty ? null : _controller.text),
          child: const Text('Emparejar'),
        ),
      ],
    );
  }
}
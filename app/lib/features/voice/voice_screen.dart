import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../radio/radio_provider.dart';
import 'voice_provider.dart';

/// Voice-assistant screen: a big push-to-talk mic button, an animated status
/// indicator, the conversation history, and a text field as a keyboard fallback.
class VoiceScreen extends ConsumerWidget {
  const VoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceProvider);

    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.backendReachable) {
      return const _UnavailableView();
    }

    return Column(
      children: [
        if (!state.asrAvailable)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic_off_outlined, size: 18, color: AppColors.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Micrófono no disponible — usa el teclado o el micrófono simulado',
                    style: TextStyle(fontSize: 12.5, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: state.history.isEmpty
              ? const _EmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: state.history.length,
                  itemBuilder: (context, i) => _TurnBubble(turn: state.history[i]),
                ),
        ),
        const _ControlBar(),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assistant_outlined,
              size: 52, color: AppColors.muted.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          const Text('¿En qué te ayudo?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onBackground)),
          const SizedBox(height: 6),
          const Text(
            'Pulsa el micrófono o escribe un comando.\nPrueba: "qué tiempo hace" · "llévame a Bilbao" · "pon música"',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// One conversation turn: the user's utterance (right) and the reply (left),
/// plus any UI action the assistant attached (station picker, "open" button).
class _TurnBubble extends ConsumerWidget {
  const _TurnBubble({required this.turn});
  final VoiceTurn turn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(turn.utterance,
                  style: const TextStyle(fontSize: 14.5, color: AppColors.onBackground)),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.assistant,
                          size: 16,
                          color: turn.acted ? AppColors.accent : AppColors.muted),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(turn.reply,
                            style: const TextStyle(
                                fontSize: 14.5, color: AppColors.onBackground)),
                      ),
                    ],
                  ),
                  if (turn.action != null) _ActionRow(action: turn.action!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The interactive part of a reply: tappable station chips (choose_station)
/// and/or an "open the screen" button (open_radio / open_media / open_nav).
class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.action});
  final VoiceUiAction action;

  static const _routes = {
    'open_radio': ('/radio', 'Abrir radio', Icons.radio),
    'open_media': ('/media', 'Abrir música', Icons.library_music),
    'open_nav': ('/maps', 'Abrir navegación', Icons.navigation),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = <Widget>[];

    // Tappable station candidates → play the chosen one.
    if (action.stations.isNotEmpty) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in action.stations)
                ActionChip(
                  avatar: const Icon(Icons.radio, size: 16, color: AppColors.accent),
                  label: Text(s.name, style: const TextStyle(fontSize: 12.5)),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.16),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                  onPressed: () => ref.read(radioProvider.notifier).play(s),
                ),
            ],
          ),
        ),
      );
    }

    // "Open the screen" shortcut.
    final route = _routes[action.type];
    if (route != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(route.$3, size: 16),
            label: Text(route.$2, style: const TextStyle(fontSize: 12.5)),
            onPressed: () => context.go(route.$1),
          ),
        ),
      );
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

/// Bottom control bar: the mic button, a status label, and a text field.
class _ControlBar extends ConsumerStatefulWidget {
  const _ControlBar();

  @override
  ConsumerState<_ControlBar> createState() => _ControlBarState();
}

class _ControlBarState extends ConsumerState<_ControlBar>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _syncPulse(String status) {
    final active =
        status == 'listening' || status == 'thinking' || status == 'speaking';
    if (active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!active && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(voiceProvider);
    _syncPulse(state.status);
    final notifier = ref.read(voiceProvider.notifier);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.glassBorder)),
      ),
      child: Row(
        children: [
          _MicButton(
            status: state.status,
            pulse: _pulse,
            onPressed: state.isBusy
                ? null
                // Dev machines have no mic pipeline; send an empty buffer and
                // let the mock driver produce a canned command.
                : () => notifier.pushToTalk(Uint8List(0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel(state.status),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _textController,
                  style: const TextStyle(color: AppColors.onBackground, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (v) {
                    notifier.sendText(v);
                    _textController.clear();
                  },
                  decoration: InputDecoration(
                    hintText: 'Escribe un comando…',
                    hintStyle: const TextStyle(color: AppColors.muted),
                    prefixIcon: const Icon(Icons.keyboard_outlined,
                        color: AppColors.muted, size: 20),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'listening':
        return 'Escuchando…';
      case 'thinking':
        return 'Procesando…';
      case 'speaking':
        return 'Hablando…';
      default:
        return 'Toca el micrófono o escribe';
    }
  }
}

/// The big round mic button with a soft pulse while busy.
class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.status,
    required this.pulse,
    required this.onPressed,
  });

  final String status;
  final AnimationController pulse;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final busy =
        status == 'listening' || status == 'thinking' || status == 'speaking';
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        final scale = busy ? 1.0 + pulse.value * 0.08 : 1.0;
        final glow = busy ? 0.5 + pulse.value * 0.5 : 0.0;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: busy
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.45 * glow),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: busy ? AppColors.primary : AppColors.surfaceVariant,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    busy ? Icons.mic : Icons.mic_none,
                    size: 30,
                    color: busy ? Colors.black87 : AppColors.onBackground,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _UnavailableView extends ConsumerWidget {
  const _UnavailableView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.assistant_outlined,
              size: 42, color: AppColors.muted.withValues(alpha: 0.7)),
          const SizedBox(height: 10),
          const Text('Asistente no disponible',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted)),
          const SizedBox(height: 2),
          const Text('No se pudo contactar con el backend',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => ref.read(voiceProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

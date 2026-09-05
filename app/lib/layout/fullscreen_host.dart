import 'package:flutter/material.dart';

/// Media/Radio full-screen content. Built by the caller — [builder] gets the
/// exit callback so it can wire taps anywhere to leave the mode.
typedef FullscreenBuilder = Widget Function(BuildContext context, VoidCallback exit);

/// A tap-to-exit full-screen overlay for now-playing content (album art,
/// spectrum visualizer). Not a route: the AppShell mounts it directly in
/// its Stack, so the Riverpod player state (shell-global) keeps running
/// behind it and the visualizer widgets render exactly as in their panels.
///
/// Tap anywhere → [onExit]. v1 is content-only (no controls), as specified.
class FullscreenHost extends StatelessWidget {
  const FullscreenHost({super.key, required this.builder, required this.onExit});

  final FullscreenBuilder builder;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        opacity: 1.0,
        child: GestureDetector(
          // Tap anywhere leaves the full-screen mode. The content itself
          // stays passive (no controls in v1).
          onTap: onExit,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: builder(context, onExit),
          ),
        ),
      ),
    );
  }
}

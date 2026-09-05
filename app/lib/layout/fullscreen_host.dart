import 'package:flutter/material.dart';

/// Media/Radio full-screen content. Built by the caller — [builder] gets the
/// exit callback so it can wire taps anywhere to leave the mode.
typedef FullscreenBuilder =
    Widget Function(BuildContext context, VoidCallback exit);

/// A tap-to-exit full-screen overlay for now-playing content (album art,
/// spectrum visualizer). Not a route: the AppShell mounts it directly in
/// its Stack, so the Riverpod player state (shell-global) keeps running
/// behind it and the visualizer widgets render exactly as in their panels.
///
/// Tap anywhere → [onExit]. v1 is content-only (no controls), as specified.
///
/// [background] defaults to pure black (album art). Pass a lighter tone for
/// visualizer content: painters draw translucent colors over it, so on
/// pure black the spectrum reads darker than inside its usual Card — using
/// the same tone as the panel surface keeps the perceived brightness.
class FullscreenHost extends StatelessWidget {
  const FullscreenHost({
    super.key,
    required this.builder,
    required this.onExit,
    this.background = Colors.black,
  });

  final FullscreenBuilder builder;
  final VoidCallback onExit;

  /// Backdrop behind the content. Album art wants pure black (the photo is
  /// the protagonist); the spectrum wants the panel's surface tone.
  final Color background;

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
            color: background,
            child: builder(context, onExit),
          ),
        ),
      ),
    );
  }
}

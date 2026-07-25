import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/progress_bar.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  late final Animation<double> _fade = CurvedAnimation(parent: _enter, curve: Curves.easeOut);
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
          .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
  late final Animation<double> _scale =
      Tween<double>(begin: 0.9, end: 1.0)
          .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _enter.forward();
    _glow.repeat(reverse: true);
    _progress.forward();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _glow.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with breathing glow
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _glow,
                          builder: (_, __) {
                            final t = Curves.easeInOut.transform(_glow.value);
                            return Container(
                              width: 460,
                              height: 460,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.35 * t),
                                    AppColors.primary.withValues(alpha: 0),
                                  ],
                                  stops: const [0, 1],
                                ),
                              ),
                            );
                          },
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset('assets/images/hilux_99.png', width: 345),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'hiluxOS',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBackground,
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('Infotainment System',
                        style: TextStyle(color: AppColors.muted, letterSpacing: 2, fontSize: 12)),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: 240,
                      child: AnimatedBuilder(
                        animation: _progress,
                        builder: (_, __) => AnimatedProgressBar(
                          value: _progress.value,
                          height: 6,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
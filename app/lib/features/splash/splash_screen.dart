import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  late final Animation<double> _glow = Tween(begin: 0.2, end: 1.0).animate(
    CurvedAnimation(parent: _fade, curve: Curves.easeIn),
  );

  @override
  void initState() {
    super.initState();
    _fade.forward();
    _progress.forward();
    _progress.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _glow,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/hilux_99.png', width: 160),
              const SizedBox(height: 24),
              const Text(
                'hiluxOS',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: AnimatedBuilder(
                  animation: _progress,
                  builder: (_, __) => LinearProgressIndicator(
                    value: _progress.value,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
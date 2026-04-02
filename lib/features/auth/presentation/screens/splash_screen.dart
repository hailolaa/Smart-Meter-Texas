import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _scaleIn = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _anim, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
    );
    _anim.forward();
    _navTimer = Timer(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      context.go(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Premium gradient background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.primaryGreen],
                ),
              ),
            ),
          ),
          // Soft overlay to increase contrast
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.10)),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _scaleIn,
                        child: _ShimmerLogo(animation: _anim),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'ElectricToday',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Login with your SMT credentials',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerLogo extends StatelessWidget {
  const _ShimmerLogo({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Shimmer sweep position from -1 to 2 across the diagonal
        final t = animation.value * 3 - 1;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.bolt_rounded, color: AppColors.primaryBlue, size: 48),
            ),
            // Shimmer overlay
            ClipOval(
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                    stops: [
                      (t - 0.10).clamp(0.0, 1.0),
                      (t).clamp(0.0, 1.0),
                      (t + 0.10).clamp(0.0, 1.0),
                    ],
                    colors: const [
                      Colors.transparent,
                      Colors.white70,
                      Colors.transparent,
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcATop,
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}


import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_images.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/glass_card.dart';

/// Futuristic Pulsing Neon Pulse & Portal Zoom Splash Screen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _introController;
  late AnimationController _exitController;

  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _portalZoomAnimation;
  late Animation<double> _exitFadeAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Continuous Pulse Wave Controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 2. Intro Stage Animation Controller
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.elasticOut),
    );

    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)),
    );

    // 3. Exit Stage Portal Zoom Animation Controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _portalZoomAnimation = Tween<double>(begin: 1.0, end: 4.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInOutExpo),
    );

    _exitFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );

    _introController.forward();

    // Trigger Portal Exit and Navigate to Home
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted) {
        _exitController.forward().then((_) {
          if (mounted) {
            context.go(AppRoutes.home);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _introController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient Background Energy Pulsing Rings
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return CustomPaint(
                size: MediaQuery.of(context).size,
                painter: EnergyPulseRingsPainter(
                  progress: _pulseController.value,
                  primaryColor: AppColors.primary,
                  secondaryColor: AppColors.income,
                ),
              );
            },
          ),

          // Portal Zoom & Fade Transition Wrap
          AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) {
              return Transform.scale(
                scale: _portalZoomAnimation.value,
                child: Opacity(
                  opacity: _exitFadeAnimation.value,
                  child: child,
                ),
              );
            },
            child: AnimatedBuilder(
              animation: _introController,
              builder: (context, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glowing Futuristic Glass Logo Card
                    Transform.scale(
                      scale: _logoScaleAnimation.value,
                      child: Opacity(
                        opacity: _logoFadeAnimation.value,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulseGlow = 24.0 + (math.sin(_pulseController.value * 2 * math.pi) * 12.0);
                            return GlassCard(
                              padding: const EdgeInsets.all(22),
                              borderRadius: 32,
                              backgroundColor: AppColors.backgroundSecondary.withValues(alpha: 0.85),
                              borderColor: AppColors.primary.withValues(alpha: 0.6),
                              shadows: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.45),
                                  blurRadius: pulseGlow + 10,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: AppColors.income.withValues(alpha: 0.2),
                                  blurRadius: pulseGlow + 30,
                                  spreadRadius: 8,
                                ),
                              ],
                              child: Image.asset(
                                AppImages.logoIcon,
                                width: 96,
                                height: 96,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  size: 64,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // App Wordmark & Tagline Fade In
                    Opacity(
                      opacity: _textFadeAnimation.value,
                      child: Column(
                        children: [
                          Image.asset(
                            AppImages.logoWordmark,
                            height: 52,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              AppConstants.appName,
                              style: AppTypography.amountDisplay.copyWith(
                                fontSize: 38,
                                color: AppColors.textPrimary,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              AppConstants.appTagline,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Painter for Expanding Energy Pulsing Concentric Rings
class EnergyPulseRingsPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  EnergyPulseRingsPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.75;

    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + (i * 0.25)) % 1.0;
      final radius = ringProgress * maxRadius;
      final opacity = (1.0 - ringProgress).clamp(0.0, 1.0) * 0.55;

      final paint = Paint()
        ..color = i % 2 == 0
            ? primaryColor.withValues(alpha: opacity)
            : secondaryColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 + (1.0 - ringProgress) * 4.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant EnergyPulseRingsPainter oldDelegate) {
    return true;
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable Background Widget featuring animated ambient glow orbs
/// and a continuous diagonal specular Glass Reflection sheen sweep
class GlassReflectionBackground extends StatefulWidget {
  final Widget child;

  const GlassReflectionBackground({
    super.key,
    required this.child,
  });

  @override
  State<GlassReflectionBackground> createState() => _GlassReflectionBackgroundState();
}

class _GlassReflectionBackgroundState extends State<GlassReflectionBackground> with SingleTickerProviderStateMixin {
  late AnimationController _reflectionController;

  @override
  void initState() {
    super.initState();
    _reflectionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Deep Midnight Base Background
        Container(
          color: AppColors.background,
        ),

        // 2. Ambient Glow Orb 1 (Top Left - Neon Cyan Glow)
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 140,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),

        // 3. Ambient Glow Orb 2 (Bottom Right - Emerald Green Glow)
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.income.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.income.withValues(alpha: 0.18),
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),

        // 4. Animated Diagonal Specular Glass Reflection Sheen Sweep
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _reflectionController,
            builder: (context, child) {
              final progress = _reflectionController.value;
              // Sweeps diagonally from top-left (-1.5) to bottom-right (2.5)
              final startX = -1.5 + (progress * 4.0);
              final startY = -1.5 + (progress * 4.0);
              final endX = startX + 0.8;
              final endY = startY + 0.8;

              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(startX, startY),
                    end: Alignment(endX, endY),
                    stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.05), // Specular Sheen Reflection
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // 5. Main Screen Content Layer
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/constants/app_color_scheme.dart';
import '../../core/constants/app_colors.dart';

/// Reusable Background Widget featuring ambient glow orbs
class GlassReflectionBackground extends StatefulWidget {
  final Widget child;

  const GlassReflectionBackground({
    super.key,
    required this.child,
  });

  @override
  State<GlassReflectionBackground> createState() => _GlassReflectionBackgroundState();
}

class _GlassReflectionBackgroundState extends State<GlassReflectionBackground> {
  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    return Stack(
      children: [
        // 1. Deep Midnight / Warm Platinum Base Background
        Container(
          color: colors.background,
        ),

        // 2. Ambient Glow Orb 1 (Top Left - Amber Sunset Glow)
        Positioned(
          top: -120,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: colors.orbColor1,
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
              color: AppColors.income.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: colors.orbColor2,
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),

        // 4. Main Screen Content Layer
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Glassmorphism Theme Helper
class GlassTheme {
  GlassTheme._();

  static const double borderRadiusSmall = 12.0;
  static const double borderRadiusMedium = 16.0;
  static const double borderRadiusLarge = 24.0;

  static const double blurSigmaX = 20.0;
  static const double blurSigmaY = 20.0;

  /// Default Glass Container Decoration
  static BoxDecoration glassDecoration({
    double borderRadius = borderRadiusMedium,
    Color surfaceColor = AppColors.glassCard,
    Color borderColor = AppColors.glassBorder,
    List<BoxShadow>? shadows,
  }) {
    return BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor,
        width: 1.0,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.1),
          Colors.white.withValues(alpha: 0.02),
        ],
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 32.0,
              spreadRadius: 0.0,
              offset: const Offset(0, 8),
            ),
          ],
    );
  }

  /// Glowing Glass Accent Decoration
  static BoxDecoration glowingGlassDecoration({
    required Color glowColor,
    double borderRadius = borderRadiusMedium,
  }) {
    return BoxDecoration(
      color: glowColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: glowColor.withValues(alpha: 0.35),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.2),
          blurRadius: 16,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}

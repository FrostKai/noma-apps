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
    Color? surfaceColor,
    Color? borderColor,
    List<BoxShadow>? shadows,
    bool isLight = false,
  }) {
    final defaultSurface = surfaceColor ?? (isLight ? const Color(0xCCFFFFFF) : AppColors.glassCard);
    final defaultBorder = borderColor ?? (isLight ? const Color(0x33000000) : AppColors.glassBorder);

    return BoxDecoration(
      color: defaultSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: defaultBorder,
        width: 1.0,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLight
            ? [
                Colors.white.withValues(alpha: 0.8),
                Colors.white.withValues(alpha: 0.5),
              ]
            : [
                Colors.white.withValues(alpha: 0.1),
                Colors.white.withValues(alpha: 0.02),
              ],
      ),
      boxShadow: shadows ??
          [
            BoxShadow(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: isLight ? 16.0 : 32.0,
              spreadRadius: 0.0,
              offset: const Offset(0, 4),
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

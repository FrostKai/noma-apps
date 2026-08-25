import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_color_scheme.dart';
import '../../core/theme/glass_theme.dart';
import 'bouncy_tap.dart';

/// Reusable Glassmorphism Card Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final bool enableBlur;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = GlassTheme.borderRadiusMedium,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.shadows,
    this.width,
    this.height,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final isLight = AppColorScheme.isLight(context);
    final bgColor = backgroundColor ?? colors.glassCard;
    final bdColor = borderColor ?? colors.glassBorder;

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: GlassTheme.glassDecoration(
        borderRadius: borderRadius,
        surfaceColor: bgColor,
        borderColor: bdColor,
        shadows: shadows,
        isLight: isLight,
      ),
      child: child,
    );

    Widget frosted = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: enableBlur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: GlassTheme.blurSigmaX,
                sigmaY: GlassTheme.blurSigmaY,
              ),
              child: content,
            )
          : content,
    );

    if (margin != null) {
      frosted = Padding(padding: margin!, child: frosted);
    }

    if (onTap != null) {
      return BouncyTap(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: onTap,
            child: frosted,
          ),
        ),
      );
    }

    return frosted;
  }
}

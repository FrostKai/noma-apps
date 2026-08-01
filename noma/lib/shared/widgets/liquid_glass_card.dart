import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import 'bouncy_tap.dart';
import 'liquid_wave_painter.dart';

/// Glass Card featuring a smooth animated flowing liquid wave ("Balance Card")
class LiquidGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.borderRadius = GlassTheme.borderRadiusLarge,
    this.backgroundColor = AppColors.glassCard,
    this.borderColor = AppColors.glassBorder,
    this.onTap,
    this.shadows,
    this.width,
    this.height,
  });

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      width: widget.width,
      height: widget.height,
      decoration: GlassTheme.glassDecoration(
        borderRadius: widget.borderRadius,
        surfaceColor: widget.backgroundColor,
        borderColor: widget.borderColor,
        shadows: widget.shadows,
      ),
      child: Stack(
        children: [
          // Animated Flowing Liquid Wave Painter Layer
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: LiquidWavePainter(
                      animationValue: _waveController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          // Main Card Content Layer
          Padding(
            padding: widget.padding ?? const EdgeInsets.all(24),
            child: widget.child,
          ),
        ],
      ),
    );

    Widget frosted = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTheme.blurSigmaX,
          sigmaY: GlassTheme.blurSigmaY,
        ),
        child: cardContent,
      ),
    );

    if (widget.margin != null) {
      frosted = Padding(padding: widget.margin!, child: frosted);
    }

    if (widget.onTap != null) {
      return BouncyTap(
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            onTap: widget.onTap,
            child: frosted,
          ),
        ),
      );
    }

    return frosted;
  }
}

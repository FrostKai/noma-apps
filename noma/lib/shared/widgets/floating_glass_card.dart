import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/glass_theme.dart';
import 'bouncy_tap.dart';

/// Reusable Glass Card with continuous subtle 3D floating & shadow pulsing animation
class FloatingGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final double floatDistance;
  final Duration duration;
  final double? width;
  final double? height;

  const FloatingGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = GlassTheme.borderRadiusMedium,
    this.backgroundColor = AppColors.glassCard,
    this.borderColor = AppColors.glassBorder,
    this.onTap,
    this.floatDistance = 6.0,
    this.duration = const Duration(milliseconds: 2800),
    this.width,
    this.height,
  });

  @override
  State<FloatingGlassCard> createState() => _FloatingGlassCardState();
}

class _FloatingGlassCardState extends State<FloatingGlassCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _translationAnimation;
  late Animation<double> _shadowBlurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);

    _translationAnimation = Tween<double>(
      begin: 0.0,
      end: -widget.floatDistance,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    _shadowBlurAnimation = Tween<double>(
      begin: 24.0,
      end: 38.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget card = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _translationAnimation.value),
          child: Container(
            width: widget.width,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: widget.borderColor,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: _shadowBlurAnimation.value,
                  spreadRadius: 0,
                  offset: Offset(0, 8 - (_translationAnimation.value * 0.5)),
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );

    Widget frosted = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassTheme.blurSigmaX,
          sigmaY: GlassTheme.blurSigmaY,
        ),
        child: card,
      ),
    );

    if (widget.margin != null) {
      frosted = Padding(padding: widget.margin!, child: frosted);
    }

    if (widget.onTap != null) {
      return BouncyTap(
        onTap: widget.onTap,
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

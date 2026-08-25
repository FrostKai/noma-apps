import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_color_scheme.dart';
import '../../core/theme/glass_theme.dart';
import 'bouncy_tap.dart';

/// Reusable Glass Card (Supports static presentation without floating motion)
class FloatingGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
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
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.floatDistance = 0.0, // Default to 0.0 (Static, no floating motion)
    this.duration = const Duration(milliseconds: 2800),
    this.width,
    this.height,
  });

  @override
  State<FloatingGlassCard> createState() => _FloatingGlassCardState();
}

class _FloatingGlassCardState extends State<FloatingGlassCard> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _translationAnimation;
  Animation<double>? _shadowBlurAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.floatDistance > 0.0) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.duration,
      )..repeat(reverse: true);

      _translationAnimation = Tween<double>(
        begin: 0.0,
        end: -widget.floatDistance,
      ).animate(
        CurvedAnimation(
          parent: _controller!,
          curve: Curves.easeInOutSine,
        ),
      );

      _shadowBlurAnimation = Tween<double>(
        begin: 24.0,
        end: 38.0,
      ).animate(
        CurvedAnimation(
          parent: _controller!,
          curve: Curves.easeInOutSine,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColorScheme.of(context);
    final isLight = AppColorScheme.isLight(context);
    final bgColor = widget.backgroundColor ?? colors.glassCard;
    final bdColor = widget.borderColor ?? colors.glassBorder;
    final shadowColor = isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.35);

    final hasMotion = widget.floatDistance > 0.0 && _controller != null;

    Widget cardContent = Container(
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: bdColor,
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
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: hasMotion ? _shadowBlurAnimation!.value : (isLight ? 16.0 : 28.0),
            spreadRadius: 0,
            offset: Offset(0, hasMotion ? 8 - (_translationAnimation!.value * 0.5) : 8),
          ),
        ],
      ),
      child: widget.child,
    );

    Widget card = hasMotion
        ? AnimatedBuilder(
            animation: _controller!,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _translationAnimation!.value),
                child: cardContent,
              );
            },
          )
        : cardContent;

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

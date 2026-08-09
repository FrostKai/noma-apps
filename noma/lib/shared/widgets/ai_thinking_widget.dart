import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'glass_card.dart';

/// Clean & Modern AI Thinking Loading Widget
class AiThinkingWidget extends StatefulWidget {
  final String text;
  final bool isCompact;
  final double size;

  const AiThinkingWidget({
    super.key,
    this.text = 'Nomi AI sedang berpikir...',
    this.isCompact = false,
    this.size = 56.0,
  });

  @override
  State<AiThinkingWidget> createState() => _AiThinkingWidgetState();
}

class _AiThinkingWidgetState extends State<AiThinkingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // ~0.8s linear infinite loop
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactThinking();
    }

    return _buildFullThinkingCard();
  }

  Widget _buildCompactThinking() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularArcSpinner(
            size: 18,
            strokeWidth: 2.5,
            controller: _controller,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          widget.text,
          style: AppTypography.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFullThinkingCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      borderRadius: 24,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      shadows: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularArcSpinner(
            size: widget.size,
            strokeWidth: 4.5,
            controller: _controller,
          ),
          const SizedBox(height: 16),
          Text(
            widget.text,
            textAlign: TextAlign.center,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular loading spinner: Round element with a thick neutral border,
/// two adjacent sides (top and right) tinted with accent color to form an arc,
/// rotating 1turn on a linear infinite loop (~0.8s).
class CircularArcSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color neutralColor;
  final Color accentColor;
  final AnimationController? controller;

  const CircularArcSpinner({
    super.key,
    this.size = 56.0,
    this.strokeWidth = 4.5,
    this.neutralColor = const Color(0x33FFFFFF),
    this.accentColor = AppColors.primary,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, child) {
          return Transform.rotate(
            angle: controller!.value * 2 * math.pi,
            child: CustomPaint(
              size: Size(size, size),
              painter: _ArcSpinnerPainter(
                strokeWidth: strokeWidth,
                neutralColor: neutralColor,
                accentColor: accentColor,
              ),
            ),
          );
        },
      );
    }

    return _StandaloneArcSpinner(
      size: size,
      strokeWidth: strokeWidth,
      neutralColor: neutralColor,
      accentColor: accentColor,
    );
  }
}

class _StandaloneArcSpinner extends StatefulWidget {
  final double size;
  final double strokeWidth;
  final Color neutralColor;
  final Color accentColor;

  const _StandaloneArcSpinner({
    required this.size,
    required this.strokeWidth,
    required this.neutralColor,
    required this.accentColor,
  });

  @override
  State<_StandaloneArcSpinner> createState() => _StandaloneArcSpinnerState();
}

class _StandaloneArcSpinnerState extends State<_StandaloneArcSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.rotate(
          angle: _ctrl.value * 2 * math.pi,
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ArcSpinnerPainter(
              strokeWidth: widget.strokeWidth,
              neutralColor: widget.neutralColor,
              accentColor: widget.accentColor,
            ),
          ),
        );
      },
    );
  }
}

class _ArcSpinnerPainter extends CustomPainter {
  final double strokeWidth;
  final Color neutralColor;
  final Color accentColor;

  _ArcSpinnerPainter({
    required this.strokeWidth,
    required this.neutralColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 1. Round element with thick neutral border
    final neutralPaint = Paint()
      ..color = neutralColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, neutralPaint);

    // 2. Tint two adjacent sides (top & right) the accent color to form an arc
    final accentPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start at top (-pi/2) and sweep 90 degrees (pi/2) for top & right adjacent sides
    canvas.drawArc(rect, -math.pi / 2, math.pi / 2, false, accentPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcSpinnerPainter oldDelegate) {
    return oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.neutralColor != neutralColor ||
        oldDelegate.accentColor != accentColor;
  }
}

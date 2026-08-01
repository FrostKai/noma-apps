import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'glass_card.dart';

/// Futuristic AI Thinking Animation Widget with rotating neural rings,
/// pulsing glowing particles, and animated wave dots
class AiThinkingWidget extends StatefulWidget {
  final String text;
  final bool isCompact;
  final double size;

  const AiThinkingWidget({
    super.key,
    this.text = 'Nomi AI sedang berpikir...',
    this.isCompact = false,
    this.size = 64.0,
  });

  @override
  State<AiThinkingWidget> createState() => _AiThinkingWidgetState();
}

class _AiThinkingWidgetState extends State<AiThinkingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: const Icon(
                Icons.auto_awesome,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            _buildBouncingDots(size: 4),
          ],
        );
      },
    );
  }

  Widget _buildFullThinkingCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      borderRadius: 24,
      borderColor: AppColors.primary.withValues(alpha: 0.4),
      shadows: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.2),
          blurRadius: 28,
          spreadRadius: 2,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Rotating Neural Orb
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Pulsing Glow Ring
                    Transform.scale(
                      scale: 1.0 + (math.sin(_controller.value * 2 * math.pi) * 0.12),
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Rotating Neural Arc 1
                    Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: CustomPaint(
                        size: Size(widget.size * 0.85, widget.size * 0.85),
                        painter: NeuralArcPainter(
                          color: AppColors.primary,
                          startAngle: 0,
                          sweepAngle: math.pi * 1.2,
                        ),
                      ),
                    ),

                    // Counter-Rotating Neural Arc 2
                    Transform.rotate(
                      angle: -_controller.value * 2 * math.pi * 1.5,
                      child: CustomPaint(
                        size: Size(widget.size * 0.65, widget.size * 0.65),
                        painter: NeuralArcPainter(
                          color: AppColors.income,
                          startAngle: math.pi * 0.5,
                          sweepAngle: math.pi * 0.8,
                        ),
                      ),
                    ),

                    // Center Glowing Sparkle Icon
                    Transform.scale(
                      scale: 0.9 + (math.cos(_controller.value * 2 * math.pi) * 0.15),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Thinking Status Text & Bouncing Wave Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.text,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              _buildBouncingDots(size: 5),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDots({required double size}) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animVal = (math.sin((_controller.value + delay) * 2 * math.pi) + 1) / 2;
            final scale = 0.5 + (animVal * 0.5);
            final opacity = 0.3 + (animVal * 0.7);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Custom Painter drawing smooth glowing neural ring arcs
class NeuralArcPainter extends CustomPainter {
  final Color color;
  final double startAngle;
  final double sweepAngle;

  NeuralArcPainter({
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
  }

  @override
  bool shouldRepaint(covariant NeuralArcPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.sweepAngle != sweepAngle;
  }
}

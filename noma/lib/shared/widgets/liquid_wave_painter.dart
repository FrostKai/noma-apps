import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Custom Painter creating a smooth, flowing liquid wave animation
class LiquidWavePainter extends CustomPainter {
  final double animationValue;
  final Color waveColorPrimary;
  final Color waveColorSecondary;

  LiquidWavePainter({
    required this.animationValue,
    this.waveColorPrimary = AppColors.primary,
    this.waveColorSecondary = AppColors.income,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final baseHeight = height * 0.45; // Wave height position

    // Wave 1 (Secondary Background Wave)
    final pathSecondary = Path();
    pathSecondary.moveTo(0, height);
    pathSecondary.lineTo(0, baseHeight);

    for (double i = 0.0; i <= width; i++) {
      final y = math.sin((i / width * 2 * math.pi) + (animationValue * 2 * math.pi)) * 12 + baseHeight + 4;
      pathSecondary.lineTo(i, y);
    }

    pathSecondary.lineTo(width, height);
    pathSecondary.close();

    final paintSecondary = Paint()
      ..shader = LinearGradient(
        colors: [
          waveColorSecondary.withValues(alpha: 0.18),
          waveColorPrimary.withValues(alpha: 0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathSecondary, paintSecondary);

    // Wave 2 (Primary Foreground Wave)
    final pathPrimary = Path();
    pathPrimary.moveTo(0, height);
    pathPrimary.lineTo(0, baseHeight + 6);

    for (double i = 0.0; i <= width; i++) {
      final y = math.sin((i / width * 2.5 * math.pi) - (animationValue * 2 * math.pi)) * 14 + baseHeight;
      pathPrimary.lineTo(i, y);
    }

    pathPrimary.lineTo(width, height);
    pathPrimary.close();

    final paintPrimary = Paint()
      ..shader = LinearGradient(
        colors: [
          waveColorPrimary.withValues(alpha: 0.22),
          waveColorSecondary.withValues(alpha: 0.08),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathPrimary, paintPrimary);
  }

  @override
  bool shouldRepaint(covariant LiquidWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

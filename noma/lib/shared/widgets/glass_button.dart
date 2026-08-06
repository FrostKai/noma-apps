import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/glass_theme.dart';

enum GlassButtonVariant { primary, secondary, income, expense, warning, outline }

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlassButtonVariant variant;
  final bool isLoading;
  final double? width;
  final double height;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = GlassButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.height = 52.0,
  });

  Color get _accentColor {
    switch (variant) {
      case GlassButtonVariant.primary:
        return AppColors.primary;
      case GlassButtonVariant.income:
        return AppColors.income;
      case GlassButtonVariant.expense:
        return AppColors.expense;
      case GlassButtonVariant.warning:
        return AppColors.warning;
      case GlassButtonVariant.secondary:
      case GlassButtonVariant.outline:
        return AppColors.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color bg = _accentColor.withValues(alpha: 0.2);
    Color border = _accentColor.withValues(alpha: 0.4);
    Color textColor = AppColors.textPrimary;

    if (variant == GlassButtonVariant.outline) {
      bg = Colors.transparent;
      border = AppColors.glassBorder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(GlassTheme.borderRadiusMedium),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: width ?? double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(GlassTheme.borderRadiusMedium),
            border: Border.all(color: border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(GlassTheme.borderRadiusMedium),
              onTap: isLoading ? null : onPressed,
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: textColor, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            label,
                            style: AppTypography.labelLarge.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

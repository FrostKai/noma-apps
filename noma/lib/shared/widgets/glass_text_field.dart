import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/glass_theme.dart';

class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final int maxLines;

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Text(
            labelText!,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(GlassTheme.borderRadiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassSurface,
                borderRadius: BorderRadius.circular(GlassTheme.borderRadiusMedium),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 1.0,
                ),
              ),
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                onChanged: onChanged,
                maxLines: maxLines,
                style: AppTypography.bodyMedium,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: prefixIcon != null
                      ? Icon(prefixIcon, color: AppColors.textSecondary, size: 20)
                      : null,
                  suffixIcon: suffixIcon,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

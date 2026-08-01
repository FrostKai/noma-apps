import 'package:flutter/material.dart';

/// Design System Color Palette for Noma App
/// Theme: "Warm Sunset Obsidian & Glass" (Harmonized with Noma Amber/Orange Logo)
class AppColors {
  AppColors._();

  // Background Colors (Deep Midnight Obsidian)
  static const Color background = Color(0xFF080A0F);
  static const Color backgroundSecondary = Color(0xFF11141D);
  static const Color surface = Color(0xFF191D2A);

  // Accent Colors (Logo Amber & Sunset Orange)
  static const Color primary = Color(0xFFFF8800); // Warm Sunset Amber from Logo
  static const Color primaryLight = Color(0xFFFFAA33); // Soft Amber Accent
  static const Color primaryDark = Color(0xFFD96E00); // Deep Amber
  static const Color income = Color(0xFF10B981); // Emerald Green for income
  static const Color expense = Color(0xFFFF4757); // Rose Coral Red for expense
  static const Color warning = Color(0xFFFFB100); // Golden Amber for warning
  static const Color info = Color(0xFF38BDF8); // Sky Blue info

  // Text Colors
  static const Color textPrimary = Color(0xFFF8F9FA); // Warm Off-White
  static const Color textSecondary = Color(0xFFA0A6B5); // Warm Muted Silver
  static const Color textMuted = Color(0xFF6B7280); // Darker Slate

  // Glassmorphism System Colors
  static const Color glassSurface = Color(0x1F191D2A); // 12% Opacity Surface
  static const Color glassCard = Color(0x26191D2A); // 15% Opacity Surface
  static const Color glassCardHover = Color(0x40191D2A); // 25% Opacity Surface
  static const Color glassBorder = Color(0x1FFFFFFF); // 12% White Border
  static const Color glassBorderGlow = Color(0x33FF8800); // 20% Amber Sunset Glow Border

  // Gradient Colors (Signature Noma Sunset Gradients)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF8800), Color(0xFFFF5500)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFF9900), Color(0xFFFF4400)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFFF4757), Color(0xFFD63031)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x33FFFFFF),
      Color(0x0DFFFFFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

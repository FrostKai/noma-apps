import 'package:flutter/material.dart';

/// Adaptive color palette — berubah mengikuti brightness (light/dark).
/// Gunakan `AppColorScheme.of(context)` di dalam widget tree.
/// Warna semantik (primary, income, expense, dll.) tetap dari AppColors.
class AppColorScheme {
  static AppColorScheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? _light : _dark;
  }

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // ── DARK (default, sama persis dengan AppColors saat ini) ────────────────
  static const _dark = AppColorScheme._dark_();
  // ── LIGHT (Warm Platinum & Frost Glass) ─────────────────────────────────
  static const _light = AppColorScheme._light_();

  // ── Warna yang harus diakses ─────────────────────────────────────────────
  Color get background        => _background;
  Color get backgroundSecondary => _backgroundSecondary;
  Color get surface           => _surface;
  Color get textPrimary       => _textPrimary;
  Color get textSecondary     => _textSecondary;
  Color get textMuted         => _textMuted;
  Color get glassSurface      => _glassSurface;
  Color get glassCard         => _glassCard;
  Color get glassBorder       => _glassBorder;
  Color get navBarBackground  => _navBarBackground;
  Color get navBarBorder      => _navBarBorder;
  Color get orbColor1         => _orbColor1; // ambient glow orb 1
  Color get orbColor2         => _orbColor2; // ambient glow orb 2
  Color get fabIconBg         => _fabIconBg;

  // Abstract fields — diisi oleh subclass konstanta
  final Color _background;
  final Color _backgroundSecondary;
  final Color _surface;
  final Color _textPrimary;
  final Color _textSecondary;
  final Color _textMuted;
  final Color _glassSurface;
  final Color _glassCard;
  final Color _glassBorder;
  final Color _navBarBackground;
  final Color _navBarBorder;
  final Color _orbColor1;
  final Color _orbColor2;
  final Color _fabIconBg;

  // ── Constructor internal ─────────────────────────────────────────────────
  const AppColorScheme._dark_()
      : _background         = const Color(0xFF080A0F),
        _backgroundSecondary= const Color(0xFF11141D),
        _surface            = const Color(0xFF191D2A),
        _textPrimary        = const Color(0xFFF8F9FA),
        _textSecondary      = const Color(0xFFA0A6B5),
        _textMuted          = const Color(0xFF6B7280),
        _glassSurface       = const Color(0x1F191D2A),
        _glassCard          = const Color(0x26191D2A),
        _glassBorder        = const Color(0x1FFFFFFF),
        _navBarBackground   = const Color(0xD911141D), // 85% opacity
        _navBarBorder       = const Color(0x1FFFFFFF),
        _orbColor1          = const Color(0x26FF8800), // amber glow
        _orbColor2          = const Color(0x1F10B981), // emerald glow
        _fabIconBg          = const Color(0xF211141D);

  const AppColorScheme._light_()
      : _background         = const Color(0xFFF4F6F9), // Warm Platinum
        _backgroundSecondary= const Color(0xFFE8EDF4), // Frost Slate
        _surface            = const Color(0xFFFFFFFF), // Pure White
        _textPrimary        = const Color(0xFF0F172A), // Midnight Ink
        _textSecondary      = const Color(0xFF475569), // Slate
        _textMuted          = const Color(0xFF94A3B8), // Light Slate
        _glassSurface       = const Color(0x14FFFFFF), // 8% white frost
        _glassCard          = const Color(0xCCFFFFFF), // 80% white card
        _glassBorder        = const Color(0x33000000), // 20% black border
        _navBarBackground   = const Color(0xF0FFFFFF), // 94% white
        _navBarBorder       = const Color(0x22000000), // 13% black border
        _orbColor1          = const Color(0x20FF8800), // amber tint
        _orbColor2          = const Color(0x1A10B981), // emerald tint
        _fabIconBg          = const Color(0xF0FFFFFF);
}

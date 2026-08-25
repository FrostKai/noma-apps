import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography Scale using Google Fonts Outfit (headings/amounts) & Inter (body)
class AppTypography {
  AppTypography._();

  // Headings & Financial Amounts (Outfit)
  static TextStyle headingXLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
  );

  static TextStyle headingLarge = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static TextStyle headingMedium = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  static TextStyle headingSmall = GoogleFonts.outfit(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static TextStyle amountDisplay = GoogleFonts.outfit(
    fontSize: 36,
    fontWeight: FontWeight.bold,
    letterSpacing: -0.5,
  );

  static TextStyle amountLarge = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  // Body Text (Inter)
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
  );

  // Labels & Captions
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.normal,
  );
}

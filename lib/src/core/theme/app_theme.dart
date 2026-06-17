import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF00759A);
  static const Color success = Color(0xFF00B894);
  static const Color successAlt = Color(0xFF2BB673);
  static const Color warning = Color(0xFFF2C94C);
  static const Color error   = Color(0xFFEB5757);
  static const Color bgLight = Color(0xFFF9FAFB);
  static const Color bgPending = Color(0xFFF6F8FA);
  static const Color successBg = Color(0xFFE9F7F2);
  static const Color cardShadow = Color(0x11000000);
  static const Color cardShadowLight = Color(0x08000000);
  static const Color cardShadowMedium = Color(0x10000000);
  static const Color accentPurple = Color(0xFF6C63FF);
  static const Color accentOrange = Color(0xFFFF8A65);
  static const Color accentTeal = Color(0xFF0E888A);
  static const Color successSoftBg = Color(0x1A2ECC71);
  static const Color successSoftBorder = Color(0x332ECC71);
  static const Color neutralLight = Color(0xFFEDEDED);

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: primary,
      brightness: Brightness.light,
    );

    return base.copyWith(
      scaffoldBackgroundColor: bgLight,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

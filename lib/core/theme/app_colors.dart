import 'package:flutter/material.dart';

/// Salwana brand palette — professional green / white / neutral, tuned for
/// commerce and inventory screens. Keep all color literals here so the app
/// reads as one consistent system.
class AppColors {
  AppColors._();

  // Brand green
  static const Color primary = Color(0xFF0F8A5F);
  static const Color primaryDark = Color(0xFF0B6B49);
  static const Color primaryLight = Color(0xFFE6F4EC);
  static const Color primarySurface = Color(0xFFF1FAF5);

  // Neutrals
  static const Color textPrimary = Color(0xFF1A1D1E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFAFB5B4);
  static const Color background = Color(0xFFF7F8F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE4E7E6);
  static const Color divider = Color(0xFFEDEFEE);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color pending = Color(0xFF6366F1);

  // Status backgrounds (for badges/chips)
  static const Color successBg = Color(0xFFE8F8EE);
  static const Color warningBg = Color(0xFFFEF3E2);
  static const Color errorBg = Color(0xFFFDECEC);
  static const Color infoBg = Color(0xFFEAF1FD);
  static const Color pendingBg = Color(0xFFEEEDFD);
  static const Color neutralBg = Color(0xFFF0F1F1);

  static const Color overlay = Color(0x66000000);
}

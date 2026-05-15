import 'package:flutter/material.dart';

/// Centralized color palette for the VIGIL app.
///
/// All colors used across the app should be referenced from here so that
/// theming stays consistent and can be swapped/extended easily later.
class AppColors {
  AppColors._();

  // ---------------------------------------------------------------------------
  // Brand / primary
  // ---------------------------------------------------------------------------
  static const Color primary = Color(0xFF22A45D); // VIGIL green
  static const Color primaryDark = Color(0xFF178A4B);
  static const Color primaryLight = Color(0xFFE7F6EE);

  // ---------------------------------------------------------------------------
  // Header gradient (deep navy -> teal-ish navy)
  // ---------------------------------------------------------------------------
  static const Color headerTop = Color(0xFF0A1A3C);
  static const Color headerBottom = Color(0xFF0E2A4A);

  // ---------------------------------------------------------------------------
  // Surfaces & background
  // ---------------------------------------------------------------------------
  static const Color scaffold = Color(0xFFF4F6FA);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFEDEFF3);
  static const Color darkCard = Color(0xFF0E2240); // "Today's Activity" panel

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1A1D29);
  static const Color textSecondary = Color(0xFF7A8194);
  static const Color textOnDark = Colors.white;
  static const Color textOnDarkMuted = Color(0xFFB9C2D4);

  // ---------------------------------------------------------------------------
  // Status
  // ---------------------------------------------------------------------------
  static const Color online = Color(0xFF22A45D);
  static const Color alert = Color(0xFFE5484D);
  static const Color badge = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);

  // ---------------------------------------------------------------------------
  // Feature tile accent colors (icon + soft bg pairs)
  // ---------------------------------------------------------------------------
  static const Color blueIcon = Color(0xFF3B82F6);
  static const Color blueSoft = Color(0xFFE8F0FE);

  static const Color greenIcon = Color(0xFF22A45D);
  static const Color greenSoft = Color(0xFFE7F6EE);

  static const Color orangeIcon = Color(0xFFF97316);
  static const Color orangeSoft = Color(0xFFFDEEE3);

  static const Color whatsappIcon = Color(0xFF25D366);
  static const Color whatsappSoft = Color(0xFFE7F8EE);

  static const Color purpleIcon = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFEFE9FB);

  static const Color indigoIcon = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEAEAFB);

  // ---------------------------------------------------------------------------
  // AI insight card gradient
  // ---------------------------------------------------------------------------
  static const Color aiCardStart = Color(0xFFF1ECFB);
  static const Color aiCardEnd = Color(0xFFFDEEF4);

  // ---------------------------------------------------------------------------
  // Misc
  // ---------------------------------------------------------------------------
  static const Color shadow = Color(0x14000000);
  static const Color mapGreenZone = Color(0x3322A45D);
}

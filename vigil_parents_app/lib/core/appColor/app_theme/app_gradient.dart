import 'package:flutter/material.dart';

/// Centralized gradient definitions for the entire app.
/// Usage: AppGradients.loginButton, AppGradients.primary, etc.
class AppGradients {
  AppGradients._(); // prevent instantiation

  // ── Brand Gradients ────────────────────────────────────────────────────────

  /// Dark navy → brand green  (Login / primary action button)
  static const LinearGradient primaryButton = LinearGradient(
    colors: [Color(0xFF1A237E), Color(0xFF2E7D32)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Loading / disabled state
  static LinearGradient disabled = LinearGradient(
    colors: [Colors.grey.shade400, Colors.grey.shade500],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Accent teal → blue  (secondary actions)
  static const LinearGradient secondary = LinearGradient(
    colors: [Color(0xFF15BEB5), Color(0xFF2BA0CC)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Soft sky blue (card backgrounds, highlights)
  static const LinearGradient softBlue = LinearGradient(
    colors: [Color(0xFFEFF3FB), Color(0xFFD6E4F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Helper ─────────────────────────────────────────────────────────────────

  /// Returns the last color of a [LinearGradient] — useful for shadow tinting.
  static Color shadowColor(LinearGradient gradient) =>
      (gradient.colors.last).withOpacity(0.35);
}

import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appimages/app_images.dart';

/// A rounded-square "icon" for an app. For well-known social apps we render the
/// real brand logo bundled in assets; otherwise the API doesn't provide icons,
/// so we fall back to a branded color (or a deterministic color derived from the
/// package name) with the app's first letter on top.
class AppIconAvatar extends StatelessWidget {
  final String appName;
  final String packageName;
  final double size;

  const AppIconAvatar({
    super.key,
    required this.appName,
    required this.packageName,
    this.size = 44,
  });

  /// Real brand logos bundled in assets, keyed by package prefix. When a match
  /// is found we show the actual logo instead of the letter fallback.
  static const Map<String, String> _brandImage = {
    'com.whatsapp': AppImages.whatsapp,
    'com.instagram.android': AppImages.insta,
    'com.snapchat.android': AppImages.snapchat,
    'com.facebook.katana': AppImages.facebook,
    'com.facebook.orca': AppImages.facebook,
  };

  static const Map<String, Color> _brand = {
    'com.whatsapp': Color(0xFF25D366),
    'com.instagram.android': Color(0xFFE1306C),
    'com.facebook.katana': Color(0xFF1877F2),
    'com.google.android.youtube': Color(0xFFFF0000),
    'com.snapchat.android': Color(0xFFFFFC00),
    'com.zhiliaoapp.musically': Color(0xFF000000), // TikTok
    'org.telegram.messenger': Color(0xFF229ED9),
    'com.spotify.music': Color(0xFF1DB954),
    'com.netflix.mediaclient': Color(0xFFE50914),
    'com.twitter.android': Color(0xFF1DA1F2),
    'com.google.android.gm': Color(0xFFD93025),
    'com.android.chrome': Color(0xFF4285F4),
  };

  static const List<Color> _palette = [
    Color(0xFF6366F1),
    Color(0xFF22A45D),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  Color get _color {
    // Match a known package, ignoring any test suffixes (e.g. "...androidrr").
    for (final entry in _brand.entries) {
      if (packageName.startsWith(entry.key)) return entry.value;
    }
    final key = packageName.isNotEmpty ? packageName : appName;
    final hash = key.codeUnits.fold<int>(0, (h, c) => h + c);
    return _palette[hash % _palette.length];
  }

  /// Resolves the bundled brand logo for [packageName], or null if none.
  String? get _image {
    for (final entry in _brandImage.entries) {
      if (packageName.startsWith(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Prefer the real brand logo when we have one bundled.
    final image = _image;
    if (image != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(image, fit: BoxFit.cover),
      );
    }

    final color = _color;
    final letter = appName.trim().isNotEmpty
        ? appName.trim()[0].toUpperCase()
        : '?';
    // Yellow brand (Snapchat) needs dark text for contrast.
    final onColor = color.computeLuminance() > 0.6
        ? Colors.black87
        : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, Color.lerp(color, Colors.black, 0.18)!],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: onColor,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.42,
        ),
      ),
    );
  }

  /// The resolved color for an app — handy for chart bars matching the avatar.
  static Color colorFor(String appName, String packageName) {
    for (final entry in _brand.entries) {
      if (packageName.startsWith(entry.key)) return entry.value;
    }
    final key = packageName.isNotEmpty ? packageName : appName;
    final hash = key.codeUnits.fold<int>(0, (h, c) => h + c);
    return _palette[hash % _palette.length];
  }
}

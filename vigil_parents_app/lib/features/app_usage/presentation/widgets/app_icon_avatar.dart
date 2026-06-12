import 'package:flutter/material.dart';

/// A rounded-square "icon" for an app. The API doesn't provide real icons, so
/// we render a branded color (for well-known apps) or a deterministic color
/// derived from the package name, with the app's first letter on top.
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

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final letter = appName.trim().isNotEmpty
        ? appName.trim()[0].toUpperCase()
        : '?';
    // Yellow brand (Snapchat) needs dark text for contrast.
    final onColor =
        color.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;

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

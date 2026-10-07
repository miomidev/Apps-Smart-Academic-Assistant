import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryLight = Color(0xFF818CF8); // Indigo 400
  static const Color primaryDark = Color(0xFF3730A3); // Indigo 800

  // Secondary & Accents
  static const Color secondary = Color(0xFF0EA5E9); // Sky 500
  static const Color accent = Color(0xFF8B5CF6); // Purple 500
  static const Color warning = Color(0xFFF59E0B); // Amber 500
  static const Color success = Color(0xFF10B981); // Emerald 500
  static const Color error = Color(0xFFEF4444); // Red 500

  // Neutral Backgrounds & Surfaces
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color border = Color(0xFFE2E8F0); // Slate 200

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Neutral Grays
  static const Color neutral100 = Color(0xFFF1F5F9); // Slate 100
  static const Color neutral200 = Color(0xFFE2E8F0); // Slate 200
  static const Color neutral300 = Color(0xFFCBD5E1); // Slate 300
  static const Color neutral400 = Color(0xFF94A3B8); // Slate 400

  // Focus Mode dark palette
  static const Color focusBackground = Color(0xFF0A0E1A);
  static const Color focusSurface = Color(0xFF161F30);
  static const Color focusAccent = Color(0xFF6366F1);

  // Course Color Presets
  static const List<Color> courseColors = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF0EA5E9), // Sky Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Coral Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
  ];

  static Color fromHex(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return primary;
    }
  }

  static String toHex(Color color) {
    return '#${(color.toARGB32()).toRadixString(16).substring(2).toUpperCase()}';
  }
}

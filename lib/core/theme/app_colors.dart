import 'package:flutter/material.dart';

/// Central color palette for the "VoiceGuard" cybersecurity aesthetic.
/// Deep blues + near-black backgrounds, neon green for safe/verified states,
/// harsh red for danger/flagged states, amber for caution/uncertain states.
class AppColors {
  AppColors._();

  // Backgrounds
  static const Color bgDeepest = Color(0xFF060A14); // near-black navy
  static const Color bgPrimary = Color(0xFF0B1120); // main scaffold bg
  static const Color bgSurface = Color(0xFF121A2E); // cards / surfaces
  static const Color bgSurfaceElevated = Color(0xFF1A2440); // raised cards
  static const Color bgInputField = Color(0xFF141D33);

  // Borders / dividers
  static const Color border = Color(0xFF243055);
  static const Color borderFocused = Color(0xFF3D5AFE);

  // Brand / accent
  static const Color accentBlue = Color(0xFF3D5AFE);
  static const Color accentCyan = Color(0xFF00E5FF);

  // Status colors
  static const Color safeGreen = Color(0xFF00FF9C); // neon green
  static const Color safeGreenDim = Color(0xFF0B3D2E);
  static const Color cautionAmber = Color(0xFFFFC400);
  static const Color dangerRed = Color(0xFFFF3B3B); // harsh red
  static const Color dangerRedDim = Color(0xFF3D0B0B);

  // Text
  static const Color textPrimary = Color(0xFFEAF0FF);
  static const Color textSecondary = Color(0xFF8C9BC4);
  static const Color textMuted = Color(0xFF5A6690);

  /// Returns a status color for a given AI risk score (0.0 - 1.0).
  static Color riskColor(double score) {
    if (score < 0.4) return safeGreen;
    if (score < 0.7) return cautionAmber;
    return dangerRed;
  }

  /// Gradient used behind hero / status elements.
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [bgDeepest, bgPrimary],
  );
}

import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF8F9FA); // Very light grey/off-white background
  static const Color cardBackground = Colors.white;

  // Text
  static const Color textMain = Color(0xFF111827); // Dark navy/slate for headers
  static const Color textMuted = Color(0xFF6B7280); // Grey for subtitles

  // Accents & Gradients
  static const Color primaryBlue = Color(0xFF2563EB); // For active icons and buttons
  static const Color primaryGreen = Color(0xFF10B981); // End of gradient
  static const Color warningOrange = Color(0xFFF59E0B); // For alerts

  // Gradient for buttons and the floating 'Energy' button
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF10B981)], // Blue to Green
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

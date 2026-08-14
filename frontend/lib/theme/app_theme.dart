import 'package:flutter/material.dart';

class AppTheme {
  // Backgrounds
  static Color backgroundColor(bool isDark) => isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC);
  
  // Orbs
  static Color orbPrimary(bool isDark) => isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD);
  static Color orbSecondary(bool isDark) => isDark ? const Color(0xFF8B5CF6) : const Color(0xFFF9A8D4);
  static Color orbWarning(bool isDark) => isDark ? const Color(0xFFEF4444) : const Color(0xFFFCA5A5);
  
  // Glassmorphism
  static Color glassBackground(bool isDark) => isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.6);
  static Color glassBorder(bool isDark) => isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
  static Color glassCard(bool isDark) => isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.8);
  static Color glassInput(bool isDark) => isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.03);

  // Text Colors
  static Color textPrimary(bool isDark) => isDark ? Colors.white : const Color(0xFF0F172A);
  static Color textSecondary(bool isDark) => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  
  // Accents
  static Color accentBlue(bool isDark) => isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
  static Color accentRed(bool isDark) => isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626);
  static Color accentGreen(bool isDark) => isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
  
  // Icons
  static Color iconColor(bool isDark) => isDark ? Colors.white : const Color(0xFF334155);
  static Color iconMuted(bool isDark) => isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
}

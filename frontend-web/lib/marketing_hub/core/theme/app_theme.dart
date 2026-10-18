import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          secondary: AppColors.goldAccent,
          surface: Colors.transparent,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: AppColors.cardBackground,
        dividerColor: AppColors.divider,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFFF8FAFC),
        ),
      );

  // Keep legacy alias
  static ThemeData get darkTheme => dark;

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: AppColors.primaryBlue,
          primary: AppColors.primaryBlue,
          secondary: const Color(0xFFD97706), // Amber 600 for light
          surface: Colors.transparent,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: const Color(0x15000000),
        dividerColor: const Color(0x20000000),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1E293B), // Dark text for light mode
        ),
      );
}


import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: AppColors.cardBackground,
          primary: AppColors.primaryBlue,
          secondary: AppColors.goldAccent,
          surface: AppColors.cardBackground,
        ),
        scaffoldBackgroundColor: AppColors.scaffoldBackground,
        cardColor: AppColors.cardBackground,
        dividerColor: AppColors.divider,
      );
}

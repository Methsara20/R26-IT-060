// Theme consumes the centralized control-room palette, type, radius, and
// surface tokens while preserving the established blue/status semantics.
import 'package:flutter/material.dart';

import 'application_design_tokens.dart';

abstract final class AppTheme {
  static const Color primary = ApplicationColors.coreAccent;
  static const Color navy = Color(0xFF12233F);
  static const Color canvas = ApplicationColors.lightBase;
  static const Color ink = ApplicationColors.lightText;
  static const Color mutedInk = ApplicationColors.lightTextMuted;
  static const Color border = ApplicationColors.lightBorder;
  static const Color success = ApplicationColors.success;
  static const Color warning = ApplicationColors.warning;
  static const Color danger = ApplicationColors.danger;

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
          surface: ApplicationColors.lightPanel,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          surface: ApplicationColors.lightPanel,
          onSurface: ink,
          outline: ApplicationColors.lightBorderStrong,
          outlineVariant: border,
          error: danger,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: ink,
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: ApplicationTypography.uiFontFallbacks,
        ),
        headlineMedium: TextStyle(
          color: ink,
          fontSize: 28,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: ApplicationTypography.uiFontFallbacks,
        ),
        headlineSmall: TextStyle(
          color: ink,
          fontSize: 24,
          height: 1.3,
          fontWeight: FontWeight.w700,
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: ApplicationTypography.uiFontFallbacks,
        ),
        titleLarge: TextStyle(
          color: ink,
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: ApplicationTypography.uiFontFallbacks,
        ),
        titleMedium: TextStyle(
          color: ink,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w600,
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: ApplicationTypography.uiFontFallbacks,
        ),
        bodyLarge: TextStyle(color: Color(0xFF475467), height: 1.5),
        bodyMedium: TextStyle(color: mutedInk, height: 1.45),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0),
      ),
      cardTheme: CardThemeData(
        color: ApplicationColors.lightPanel,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF101828).withValues(alpha: 0.06),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ApplicationRadii.card),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ApplicationColors.lightPanel,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: Color(0xFF475467)),
        hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
        errorMaxLines: 2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ApplicationRadii.control),
          borderSide: const BorderSide(
            color: ApplicationColors.lightBorderStrong,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ApplicationRadii.control),
          borderSide: const BorderSide(
            color: ApplicationColors.lightBorderStrong,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          side: const BorderSide(color: Color(0xFFB8C0CF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF8FAFC),
        selectedColor: const Color(0xFFE7EEFF),
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        labelStyle: const TextStyle(color: Color(0xFF475467)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: const TextStyle(
          color: ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: ink,
          borderRadius: BorderRadius.circular(7),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primary),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? const Color(0xFF98A2B3)
              : const Color(0xFFC7CED9),
        ),
      ),
    );
  }

  static ThemeData get dark {
    const darkCanvas = ApplicationColors.darkBase;
    const darkSurface = ApplicationColors.darkPanel;
    const darkBorder = ApplicationColors.darkBorder;
    const darkText = ApplicationColors.darkText;
    const darkMuted = ApplicationColors.darkTextMuted;
    final base = light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
          surface: darkSurface,
        ).copyWith(
          primary: ApplicationColors.coreAccentDark,
          onPrimary: Colors.white,
          surface: darkSurface,
          onSurface: darkText,
          outline: const Color(0xFF64748B),
          outlineVariant: darkBorder,
          error: const Color(0xFFFF716A),
        );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkCanvas,
      textTheme: base.textTheme.apply(
        bodyColor: darkText,
        displayColor: darkText,
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, space: 1),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: darkSurface,
        labelStyle: const TextStyle(color: darkMuted),
        hintStyle: const TextStyle(color: Color(0xFF7F8CA1)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF526078)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF1D2A40),
        selectedColor: const Color(0xFF243B6B),
        side: const BorderSide(color: darkBorder),
        labelStyle: const TextStyle(color: darkText),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: darkSurface,
        titleTextStyle: const TextStyle(
          color: darkText,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(color: darkSurface),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: const Color(0xFF243044),
      ),
      scrollbarTheme: base.scrollbarTheme.copyWith(
        thumbColor: const WidgetStatePropertyAll(Color(0xFF64748B)),
      ),
    );
  }
}

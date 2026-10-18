// Central, presentation-only tokens for the Smart Inventory interface.
import 'package:flutter/material.dart';

abstract final class ApplicationColors {
  static const coreAccent = Color(0xFF2563EB);
  static const coreAccentDark = Color(0xFF60A5FA);
  static const indigo = Color(0xFF4F46E5);
  static const indigoDark = Color(0xFF818CF8);
  static const aiAccent = Color(0xFF7C3AED);
  static const aiAccentDark = Color(0xFFA78BFA);

  static const lightBase = Color(0xFFF5F7FB);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightPanelMuted = Color(0xFFF8FAFC);
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightBorderStrong = Color(0xFFCBD5E1);
  static const lightText = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF64748B);

  static const darkBase = Color(0xFF0B1220);
  static const darkPanel = Color(0xFF111A2E);
  static const darkPanelMuted = Color(0xFF18233A);
  static const darkBorder = Color(0xFF26334A);
  static const darkBorderStrong = Color(0xFF475569);
  static const darkText = Color(0xFFE5E7EB);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFFAAB5C6);

  static const success = Color(0xFF059669);
  static const successDark = Color(0xFF34D399);
  static const warning = Color(0xFFD97706);
  static const warningDark = Color(0xFFFBBF24);
  static const danger = Color(0xFFDC2626);
  static const dangerDark = Color(0xFFF87171);
  static const information = Color(0xFF2563EB);
  static const informationDark = Color(0xFF60A5FA);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  static Color panel(BuildContext context) =>
      isDark(context) ? darkPanel : lightPanel;
  static Color panelMuted(BuildContext context) =>
      isDark(context) ? darkPanelMuted : lightPanelMuted;
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;
  static Color borderStrong(BuildContext context) =>
      isDark(context) ? darkBorderStrong : lightBorderStrong;
  static Color ai(BuildContext context) =>
      isDark(context) ? aiAccentDark : aiAccent;
  static Color status(
    BuildContext context,
    ApplicationStatusColor tone,
  ) => switch (tone) {
    ApplicationStatusColor.success => isDark(context) ? successDark : success,
    ApplicationStatusColor.warning => isDark(context) ? warningDark : warning,
    ApplicationStatusColor.danger => isDark(context) ? dangerDark : danger,
    ApplicationStatusColor.information =>
      isDark(context) ? informationDark : information,
  };
}

enum ApplicationStatusColor { success, warning, danger, information }

abstract final class ApplicationSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const compact = 12.0;
  static const medium = 16.0;
  static const comfortable = 20.0;
  static const large = 24.0;
  static const xLarge = 32.0;
  static const xxLarge = 40.0;
  static const section = 48.0;
  static const hero = 64.0;
}

abstract final class ApplicationRadii {
  static const control = 10.0;
  static const card = 16.0;
  static const dialog = 20.0;
  static const largeSurface = 22.0;
  static const pill = 999.0;
}

abstract final class ApplicationBreakpoints {
  static const mobile = 600.0;
  static const tablet = 900.0;
  static const desktop = 1200.0;
  static const wideDesktop = 1440.0;
}

abstract final class ApplicationMotion {
  static const fast = Duration(milliseconds: 140);
  static const standard = Duration(milliseconds: 220);
  static const reveal = Duration(milliseconds: 360);
  static const curve = Curves.easeOutCubic;
}

abstract final class ApplicationElevation {
  static const none = <BoxShadow>[];
  static const subtle = <BoxShadow>[
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x140F172A), blurRadius: 28, offset: Offset(0, 10)),
  ];

  static List<BoxShadow> forBrightness(
    Brightness brightness, {
    bool raised = false,
  }) => brightness == Brightness.dark
      ? none
      : (raised ? ApplicationElevation.raised : subtle);
}

abstract final class ApplicationTypography {
  static const uiFontFamily = 'Space Grotesk';
  static const uiFontFallbacks = <String>['Segoe UI', 'Inter', 'sans-serif'];
  static const dataFontFamily = 'Roboto Mono';
  static const dataFontFallbacks = <String>['Consolas', 'monospace'];

  static TextStyle data(
    BuildContext context, {
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) => TextStyle(
    fontFamily: dataFontFamily,
    fontFamilyFallback: dataFontFallbacks,
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: fontSize,
    height: 1.2,
    fontWeight: fontWeight,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}

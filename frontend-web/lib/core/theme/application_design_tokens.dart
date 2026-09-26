// Central design tokens define the restrained retail control-room visual system
// used by the theme and every shared presentation primitive.
import 'package:flutter/material.dart';


abstract final class ApplicationColors {
  static const coreAccent = Color(0xFF155EEF);
  static const coreAccentDark = Color(0xFF4F83FF);
  static const aiAccent = Color(0xFF6D5CE7);
  static const aiAccentDark = Color(0xFF9B8CFF);

  static const lightBase = Color(0xFFF5F7FB);
  static const lightPanel = Color(0xFFFFFFFF);
  static const lightPanelMuted = Color(0xFFF8FAFC);
  static const lightBorder = Color(0xFFE1E6EF);
  static const lightBorderStrong = Color(0xFFB8C0CF);
  static const lightText = Color(0xFF172033);
  static const lightTextSecondary = Color(0xFF475467);
  static const lightTextMuted = Color(0xFF667085);

  static const darkBase = Color(0xFF0D1117);
  static const darkPanel = Color(0xFF131826);
  static const darkPanelMuted = Color(0xFF192131);
  static const darkBorder = Color(0xFF1F2837);
  static const darkBorderStrong = Color(0xFF526078);
  static const darkText = Color(0xFFE7ECF4);
  static const darkTextMuted = Color(0xFFAAB5C6);

  static const success = Color(0xFF079455);
  static const warning = Color(0xFFF79009);
  static const danger = Color(0xFFD92D20);

  static Color panel(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkPanel : lightPanel;

  static Color panelMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkPanelMuted
      : lightPanelMuted;

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? darkBorder
      : lightBorder;

  static Color ai(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? aiAccentDark : aiAccent;
}

abstract final class ApplicationSpacing {
  static const xSmall = 4.0;
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const xLarge = 32.0;
}

abstract final class ApplicationRadii {
  static const control = 10.0;
  static const card = 14.0;
  static const dialog = 18.0;
  static const pill = 999.0;
}

abstract final class ApplicationTypography {
  // Browser/system fallbacks keep the build dependency-free. Bundled fonts can
  // replace these families later without changing component code.
  static const uiFontFallbacks = <String>['Space Grotesk', 'Segoe UI'];
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
    fontWeight: fontWeight,
    color: color ?? Theme.of(context).colorScheme.onSurface,
  );
}

import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/inventory_application_shell.dart';
import 'marketing_hub/core/theme/theme_notifier.dart';
import 'marketing_hub/screens/root_nav.dart';
import 'screens/landing_screen.dart';

void main() {
  runApp(const SmartInventoryApplication());
}

class SmartInventoryApplication extends StatefulWidget {
  const SmartInventoryApplication({super.key});

  @override
  State<SmartInventoryApplication> createState() =>
      _SmartInventoryApplicationState();
}

class _SmartInventoryApplicationState extends State<SmartInventoryApplication> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    // Start dark and listen for changes
    ThemeNotifier.instance.value = ThemeMode.dark;
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() => _themeMode = ThemeNotifier.instance.value);
  }

  @override
  Widget build(BuildContext context) {
    Widget buildApplicationShell(BuildContext context) =>
        InventoryApplicationShell(
          themeMode: _themeMode,
          onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
        );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Inventory',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LandingScreen(),
        '/inventory': (context) => buildApplicationShell(context),
        '/marketing': (context) => const RootNav(),
      },
    );
  }
}


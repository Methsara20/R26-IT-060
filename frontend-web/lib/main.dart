import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/inventory_application_shell.dart';

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
      // Flutter Web passes the browser location as the initial named route.
      // Accept it explicitly so module query parameters survive a refresh.
      onGenerateInitialRoutes: (initialRoute) => [
        MaterialPageRoute<void>(
          settings: RouteSettings(name: initialRoute),
          builder: buildApplicationShell,
        ),
      ],
      onGenerateRoute: (settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: buildApplicationShell,
      ),
    );
  }
}

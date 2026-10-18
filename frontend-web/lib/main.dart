import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/auth/inventory_auth_scope.dart';
import 'core/auth/inventory_auth_guard.dart';
import 'core/auth/inventory_session_controller.dart';
import 'services/inventory_auth_api_service.dart';
import 'features/shell/inventory_application_shell.dart';
import 'marketing_hub/core/theme/theme_notifier.dart';
import 'marketing_hub/core/auth/marketing_auth_scope.dart';
import 'marketing_hub/core/auth/marketing_session_controller.dart';
import 'marketing_hub/services/marketing_auth_service.dart';
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
  late final InventoryAuthApiService _inventoryApi;
  late final InventorySessionController _inventorySession;
  late final MarketingAuthService _marketingApi;
  late final MarketingSessionController _marketingSession;

  @override
  void initState() {
    super.initState();
    _inventoryApi = InventoryAuthApiService();
    _inventorySession = InventorySessionController(api: _inventoryApi);
    _marketingApi = MarketingAuthService();
    _marketingSession = MarketingSessionController(api: _marketingApi);
    // Start dark and listen for changes
    ThemeNotifier.instance.value = ThemeMode.dark;
    ThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeNotifier.instance.removeListener(_onThemeChanged);
    _inventorySession.dispose();
    _inventoryApi.close();
    _marketingSession.dispose();
    _marketingApi.close();
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
      title: 'Smart Omni-Retail',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      initialRoute: '/login',
      routes: {
        '/login': (context) => InventoryAuthScope(
          session: _inventorySession,
          child: MarketingAuthScope(
            session: _marketingSession,
            child: const LandingScreen(),
          ),
        ),
        '/inventory': (context) => InventoryAuthenticatedRoute(
          session: _inventorySession,
          builder: buildApplicationShell,
        ),
        '/marketing': (context) => MarketingAuthScope(
          session: _marketingSession,
          child: AnimatedBuilder(
            animation: _marketingSession,
            builder: (context, _) => _marketingSession.isAuthenticated
                ? const RootNav()
                : InventoryAuthScope(
                    session: _inventorySession,
                    child: const LandingScreen(),
                  ),
          ),
        ),
      },
    );
  }
}

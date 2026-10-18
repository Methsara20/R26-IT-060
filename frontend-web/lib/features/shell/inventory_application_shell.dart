import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/application_design_tokens.dart';
import '../../core/auth/inventory_auth_scope.dart';
import '../../core/auth/inventory_ui_permissions.dart';
import '../user_management/user_management_screen.dart';
import '../profile/my_profile_screen.dart';
import '../marketing_requests/marketing_requests_screen.dart';

import '../dashboard/inventory_decision_dashboard_screen.dart';
import '../analytics/inventory_analytics_screen.dart';
import '../assistant/manager_assistant_screen.dart';
import '../assistant/widgets/floating_inventory_agent.dart';
import '../assistant/inventory_assistant_suggestions.dart';
import '../forecasting/forecasting_overview_screen.dart';
import '../inventory/inventory_intelligence_screen.dart';
import '../optimization/optimization_candidates_screen.dart';
import '../stock_movements/stock_movements_screen.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import 'module_development_placeholder.dart';
import 'widgets/sidebar_support_panel.dart';

bool _canOpenDestination(BuildContext context, int index) {
  final user = InventoryAuthScope.of(context).user;
  return user != null &&
      (index != 7 || InventoryUiPermissions(user).canManageUsers) &&
      (index != 9 ||
          InventoryUiPermissions(
            user,
          ).can(InventoryOperation.readMarketingRequests));
}

List<int> _visibleDestinations(BuildContext context) => [
  for (var index = 0; index < 10; index++)
    if (_canOpenDestination(context, index)) index,
];

void _logout(BuildContext context) {
  InventoryAuthScope.read(context).logout();
  Navigator.pushReplacementNamed(context, '/login');
}

class InventoryApplicationShell extends StatefulWidget {
  const InventoryApplicationShell({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<InventoryApplicationShell> createState() =>
      _InventoryApplicationShellState();
}

class _InventoryApplicationShellState extends State<InventoryApplicationShell>
    with WidgetsBindingObserver {
  static const _moduleSlugs = <String>[
    'dashboard',
    'forecasting',
    'inventory-intelligence',
    'optimization',
    'stock-movements',
    'analytics',
    'manager-assistant',
    'user-management',
    'my-profile',
    'marketing-requests',
  ];

  static const _destinations = <_ApplicationDestination>[
    _ApplicationDestination(
      label: 'Dashboard',
      description: 'Retail operations and inventory decision overview',
      icon: Icons.space_dashboard_outlined,
      selectedIcon: Icons.space_dashboard,
    ),
    _ApplicationDestination(
      label: 'Forecasting',
      description: 'Demand forecasts, confidence, and weather context',
      icon: Icons.show_chart_outlined,
      selectedIcon: Icons.show_chart,
    ),
    _ApplicationDestination(
      label: 'Inventory Intelligence',
      description: 'Stock health, risks, coverage, and recommended actions',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _ApplicationDestination(
      label: 'Optimization',
      description: 'Transfer candidates, source selection, and explanations',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub,
    ),
    _ApplicationDestination(
      label: 'Stock Movements',
      description: 'Review and track the stock movement workflow',
      icon: Icons.swap_horiz_outlined,
      selectedIcon: Icons.swap_horiz,
    ),
    _ApplicationDestination(
      label: 'Analytics',
      description: 'Showroom, category, brand, and inventory analytics',
      icon: Icons.analytics_outlined,
      selectedIcon: Icons.analytics,
    ),
    _ApplicationDestination(
      label: 'Manager Assistant',
      description: 'Decision support conversations and chat history',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum,
    ),
    _ApplicationDestination(
      label: 'User Management',
      description: 'Inventory accounts and store permissions',
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts,
    ),
    _ApplicationDestination(
      label: 'My Profile',
      description: 'Your Inventory account and password',
      icon: Icons.account_circle_outlined,
      selectedIcon: Icons.account_circle,
    ),
    _ApplicationDestination(
      label: 'Marketing Requests',
      description: 'Review Marketing campaign stock and demand requests',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
    ),
  ];

  int _selectedIndex = 0;
  String? _forecastStoreId;
  String? _forecastProductId;
  late final InventoryDecisionWorkflowController _workflowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = _indexFromLocation(Uri.base);
    _workflowController = InventoryDecisionWorkflowController();
    _workflowController.addListener(_refreshWorkflowConsumers);
    // Normalize URLs produced by older builds after the first frame. This
    // removes accumulated hash fragments while retaining the selected module.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateBrowserLocation(_selectedIndex);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workflowController.removeListener(_refreshWorkflowConsumers);
    _workflowController.dispose();
    super.dispose();
  }

  void _refreshWorkflowConsumers() {
    if (mounted) setState(() {});
  }

  void _selectDestination(int index) {
    if (index < 0 ||
        index >= _destinations.length ||
        !_canOpenDestination(context, index)) {
      return;
    }
    setState(() => _selectedIndex = index);
    _updateBrowserLocation(index);
  }

  /// Restores the selected module after a browser refresh without persisting
  /// any workflow data or changing the application's backend contracts.
  int _indexFromLocation(Uri uri) {
    var module = uri.queryParameters['module'];
    if (module == null && uri.fragment.isNotEmpty) {
      final fragmentRoute = Uri.tryParse(uri.fragment);
      module = fragmentRoute?.queryParameters['module'];
    }
    final index = _moduleSlugs.indexOf(module ?? '');
    return index < 0 ? 0 : index;
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    final fragment = Uri.tryParse(uri.fragment);
    if (!uri.queryParameters.containsKey('module') &&
        !(fragment?.queryParameters.containsKey('module') ?? false)) {
      return false;
    }
    if (!mounted) return false;
    // Preserve the requested destination, but build never mounts denied pages.
    setState(() => _selectedIndex = _indexFromLocation(uri));
    return true;
  }

  void _updateBrowserLocation(int index) {
    // Supply a clean application route instead of mutating Uri.base. Reusing
    // Uri.base included its previous hash and caused module URLs to accumulate.
    SystemNavigator.routeInformationUpdated(
      uri: Uri(path: '/', queryParameters: {'module': _moduleSlugs[index]}),
      replace: true,
    );
  }

  void _openInventoryIntelligence() => _selectDestination(2);
  void _openOptimization() => _selectDestination(3);
  void _openStockMovement() => _selectDestination(4);
  void _openManagerAssistant() => _selectDestination(6);

  void _openForecastForInventory(String storeId, String productId) {
    setState(() {
      _forecastStoreId = storeId;
      _forecastProductId = productId;
      _selectedIndex = 1;
    });
    _updateBrowserLocation(1);
  }

  @override
  Widget build(BuildContext context) {
    final session = InventoryAuthScope.of(context);
    if (!session.isAuthenticated) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Sign in to access Inventory.'),
          ),
        ),
      );
    }
    final permitted = _canOpenDestination(context, _selectedIndex);
    final destination = _destinations[_selectedIndex];
    return LayoutBuilder(
      builder: (context, constraints) {
        final showFullSidebar = constraints.maxWidth >= 1100;
        final showNavigationRail =
            constraints.maxWidth >= 760 && !showFullSidebar;
        final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 28.0;
        return Scaffold(
          appBar: constraints.maxWidth < 760
              ? AppBar(
                  title: const _ExpandedBrand(),
                  backgroundColor: ApplicationColors.panel(context),
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                )
              : null,
          drawer: constraints.maxWidth < 760
              ? Drawer(
                  child: SafeArea(
                    child: _FullNavigation(
                      selectedIndex: _selectedIndex,
                      onSelected: (index) {
                        _selectDestination(index);
                        Navigator.of(context).pop();
                      },
                      themeMode: widget.themeMode,
                      onThemeModeChanged: widget.onThemeModeChanged,
                    ),
                  ),
                )
              : null,
          body: Row(
            children: [
              if (showFullSidebar)
                SizedBox(
                  width: 272,
                  child: _FullNavigation(
                    selectedIndex: _selectedIndex,
                    onSelected: _selectDestination,
                    themeMode: widget.themeMode,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                )
              else if (showNavigationRail)
                _CompactNavigation(
                  selectedIndex: _selectedIndex,
                  onSelected: _selectDestination,
                  themeMode: widget.themeMode,
                  onThemeModeChanged: widget.onThemeModeChanged,
                ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SelectionArea(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            constraints.maxWidth < 600 ? 20 : 32,
                            horizontalPadding,
                            48,
                          ),
                          child: !permitted
                              ? const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Inventory access denied. Global Admin access is required.',
                                  ),
                                )
                              : _selectedIndex == 0
                              ? InventoryDecisionDashboardScreen(
                                  onOpenInventoryIntelligence:
                                      _openInventoryIntelligence,
                                  onOpenOptimization: _openOptimization,
                                  onOpenMovements: _openStockMovement,
                                  onOpenAnalytics: () => _selectDestination(5),
                                )
                              : _selectedIndex == 1
                              ? ForecastingOverviewScreen(
                                  key: ValueKey(
                                    '$_forecastStoreId-$_forecastProductId',
                                  ),
                                  workflowController: _workflowController,
                                  initialStoreId: _forecastStoreId,
                                  initialProductId: _forecastProductId,
                                  onOpenIntelligence:
                                      _openInventoryIntelligence,
                                  onOpenOptimization: _openOptimization,
                                  onOpenMovement: _openStockMovement,
                                  onAskAssistant: _openManagerAssistant,
                                )
                              : _selectedIndex == 2
                              ? InventoryIntelligenceScreen(
                                  workflowController: _workflowController,
                                  onRunForecast: _openForecastForInventory,
                                )
                              : _selectedIndex == 3
                              ? OptimizationCandidatesScreen(
                                  key: ValueKey(
                                    _workflowController.current?.candidate?.id,
                                  ),
                                  workflowController: _workflowController,
                                  onOpenMovement: _openStockMovement,
                                )
                              : _selectedIndex == 4
                              ? StockMovementsScreen(
                                  key: ValueKey(_workflowController.movementId),
                                  workflowController: _workflowController,
                                  onOpenAnalytics: () => _selectDestination(5),
                                  onAskAssistant: _openManagerAssistant,
                                )
                              : _selectedIndex == 5
                              ? InventoryAnalyticsScreen(
                                  workflowController: _workflowController,
                                  onOpenInventoryIntelligence:
                                      _openInventoryIntelligence,
                                )
                              : _selectedIndex == 6
                              ? ManagerAssistantScreen(
                                  key: ValueKey(_workflowController.movementId),
                                  workflowController: _workflowController,
                                  initialMovementId:
                                      _workflowController.movementId,
                                )
                              : _selectedIndex == 7
                              ? const UserManagementScreen()
                              : _selectedIndex == 8
                              ? const MyProfileScreen()
                              : _selectedIndex == 9
                              ? const MarketingRequestsScreen()
                              : ModuleDevelopmentPlaceholder(
                                  title: destination.label,
                                  description: destination.description,
                                  icon: destination.selectedIcon,
                                ),
                        ),
                      ),
                    ),
                    if (_selectedIndex < 6 && permitted)
                      FloatingInventoryAgent(
                        moduleName: destination.label,
                        suggestions: inventoryAssistantSuggestions(
                          resolveInventoryAssistantContext(
                            workflow: _workflowController.current,
                            movementId: _workflowController.movementId,
                          ),
                        ),
                        workflowController: _workflowController,
                        onOpenFullAssistant: _openManagerAssistant,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullNavigation extends StatefulWidget {
  const _FullNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_FullNavigation> createState() => _FullNavigationState();
}

class _FullNavigationState extends State<_FullNavigation> {
  final _scrollController = ScrollController();
  final _itemKeys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant _FullNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _itemKeys[widget.selectedIndex]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indices = _visibleDestinations(context);
    // ListTile paints its selected background and ink response on the nearest
    // Material ancestor. Using Material here keeps those effects visible over
    // the sidebar background on current Flutter versions.
    return LayoutBuilder(
      builder: (context, constraints) => Material(
        color: ApplicationColors.panel(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: _ExpandedBrand(),
            ),
            Divider(color: ApplicationColors.border(context), height: 1),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: constraints.maxHeight < 700,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  // Keep this small, fixed destination set mounted so the
                  // selected route can always be revealed on short screens.
                  // ignore: deprecated_member_use
                  cacheExtent: 2000,
                  children: _navigationChildren(context, indices),
                ),
              ),
            ),
            Divider(color: ApplicationColors.border(context), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                textColor: Theme.of(context).colorScheme.onSurface,
                iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onTap: () => _logout(context),
              ),
            ),
            SidebarSupportPanel(
              themeMode: widget.themeMode,
              onThemeModeChanged: widget.onThemeModeChanged,
              compact: constraints.maxHeight < 720,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _navigationChildren(BuildContext context, List<int> indices) {
    final children = <Widget>[];
    String? previousGroup;
    for (final index in indices) {
      final group = index <= 6
          ? 'Operations'
          : index <= 8
          ? 'Account'
          : 'Collaboration';
      if (group != previousGroup) {
        children.add(_NavigationGroupLabel(group));
        previousGroup = group;
      }
      final destination = _InventoryApplicationShellState._destinations[index];
      final isSelected = widget.selectedIndex == index;
      children.add(
        Padding(
          key: _itemKeys.putIfAbsent(index, GlobalKey.new),
          padding: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            selected: isSelected,
            hoverColor: ApplicationColors.panelMuted(context),
            focusColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: .18),
            minTileHeight: 50,
            horizontalTitleGap: 12,
            titleTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            leading: Icon(
              isSelected ? destination.selectedIcon : destination.icon,
            ),
            title: Text(destination.label),
            textColor: Theme.of(context).colorScheme.onSurface,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            selectedColor: Colors.white,
            selectedTileColor: ApplicationColors.coreAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => widget.onSelected(index),
          ),
        ),
      );
    }
    return children;
  }
}

class _CompactNavigation extends StatefulWidget {
  const _CompactNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.themeMode,
    required this.onThemeModeChanged,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<_CompactNavigation> createState() => _CompactNavigationState();
}

class _CompactNavigationState extends State<_CompactNavigation> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _revealSelection();
  }

  @override
  void didUpdateWidget(covariant _CompactNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _revealSelection();
  }

  void _revealSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final indices = _visibleDestinations(context);
      final position = indices.indexOf(widget.selectedIndex);
      if (position < 0) return;
      final target = (position * 72.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indices = _visibleDestinations(context);
    return Material(
      color: ApplicationColors.panel(context),
      child: SizedBox(
        width: 96,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: _BrandMark(),
            ),
            Divider(color: ApplicationColors.border(context), height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: IntrinsicHeight(
                  child: NavigationRail(
                    backgroundColor: ApplicationColors.panel(context),
                    selectedIndex: indices.contains(widget.selectedIndex)
                        ? indices.indexOf(widget.selectedIndex)
                        : null,
                    onDestinationSelected: (position) =>
                        widget.onSelected(indices[position]),
                    labelType: NavigationRailLabelType.all,
                    indicatorColor: ApplicationColors.coreAccent,
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    selectedLabelTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                    ),
                    unselectedIconTheme: IconThemeData(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    destinations: [
                      for (final index in indices)
                        NavigationRailDestination(
                          icon: Tooltip(
                            message: _InventoryApplicationShellState
                                ._destinations[index]
                                .label,
                            child: Icon(
                              _InventoryApplicationShellState
                                  ._destinations[index]
                                  .icon,
                            ),
                          ),
                          selectedIcon: Tooltip(
                            message: _InventoryApplicationShellState
                                ._destinations[index]
                                .label,
                            child: Icon(
                              _InventoryApplicationShellState
                                  ._destinations[index]
                                  .selectedIcon,
                            ),
                          ),
                          label: Text(
                            index >= 7
                                ? _InventoryApplicationShellState
                                      ._destinations[index]
                                      .label
                                : _InventoryApplicationShellState
                                      ._destinations[index]
                                      .label
                                      .split(' ')
                                      .first,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(color: ApplicationColors.border(context), height: 1),
            IconButton(
              tooltip: widget.themeMode == ThemeMode.dark
                  ? 'Use light mode'
                  : 'Use dark mode',
              onPressed: () => widget.onThemeModeChanged(
                widget.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
              icon: Icon(
                widget.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Log out',
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _NavigationGroupLabel extends StatelessWidget {
  const _NavigationGroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    ),
  );
}

class _ExpandedBrand extends StatelessWidget {
  const _ExpandedBrand();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _BrandMark(),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Inventory',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Stock Flow Optimization',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: ApplicationColors.coreAccent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ApplicationColors.border(context)),
      ),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.white),
    );
  }
}

class _ApplicationDestination {
  const _ApplicationDestination({
    required this.label,
    required this.description,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final String description;
  final IconData icon;
  final IconData selectedIcon;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
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

class _InventoryApplicationShellState extends State<InventoryApplicationShell> {
  static const _moduleSlugs = <String>[
    'dashboard',
    'forecasting',
    'inventory-intelligence',
    'optimization',
    'stock-movements',
    'analytics',
    'manager-assistant',
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
  ];

  int _selectedIndex = 0;
  String? _forecastStoreId;
  String? _forecastProductId;
  late final InventoryDecisionWorkflowController _workflowController;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexFromBrowserLocation();
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
    _workflowController.removeListener(_refreshWorkflowConsumers);
    _workflowController.dispose();
    super.dispose();
  }

  void _refreshWorkflowConsumers() {
    if (mounted) setState(() {});
  }

  void _selectDestination(int index) {
    if (index < 0 || index >= _destinations.length) return;
    setState(() => _selectedIndex = index);
    _updateBrowserLocation(index);
  }

  /// Restores the selected module after a browser refresh without persisting
  /// any workflow data or changing the application's backend contracts.
  int _indexFromBrowserLocation() {
    var module = Uri.base.queryParameters['module'];
    if (module == null && Uri.base.fragment.isNotEmpty) {
      final fragmentRoute = Uri.tryParse(Uri.base.fragment);
      module = fragmentRoute?.queryParameters['module'];
    }
    final index = _moduleSlugs.indexOf(module ?? '');
    return index < 0 ? 0 : index;
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
                  backgroundColor: AppTheme.navy,
                  foregroundColor: Colors.white,
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
                          child: _selectedIndex == 0
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
                              : ModuleDevelopmentPlaceholder(
                                  title: destination.label,
                                  description: destination.description,
                                  icon: destination.selectedIcon,
                                ),
                        ),
                      ),
                    ),
                    if (_selectedIndex != 6)
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

class _FullNavigation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // ListTile paints its selected background and ink response on the nearest
    // Material ancestor. Using Material here keeps those effects visible over
    // the sidebar background on current Flutter versions.
    return Material(
      color: AppTheme.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: _ExpandedBrand(),
          ),
          const Divider(color: Color(0xFF30415F), height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _InventoryApplicationShellState._destinations.length,
              itemBuilder: (context, index) {
                final destination =
                    _InventoryApplicationShellState._destinations[index];
                final isSelected = selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    selected: isSelected,
                    hoverColor: const Color(0xFF1A3155),
                    leading: Icon(
                      isSelected ? destination.selectedIcon : destination.icon,
                    ),
                    title: Text(destination.label),
                    textColor: const Color(0xFFCAD4E5),
                    iconColor: const Color(0xFF9FACC2),
                    selectedColor: Colors.white,
                    selectedTileColor: const Color(0xFF155EEF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => onSelected(index),
                  ),
                );
              },
            ),
          ),
          SidebarSupportPanel(
            themeMode: themeMode,
            onThemeModeChanged: onThemeModeChanged,
          ),
        ],
      ),
    );
  }
}

class _CompactNavigation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return NavigationRail(
      backgroundColor: AppTheme.navy,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
      ),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF9FACC2)),
      unselectedLabelTextStyle: const TextStyle(
        color: Color(0xFFCAD4E5),
        fontSize: 11,
      ),
      leading: const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: _BrandMark(),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: IconButton(
          tooltip: themeMode == ThemeMode.dark
              ? 'Use light mode'
              : 'Use dark mode',
          onPressed: () => onThemeModeChanged(
            themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
          ),
          icon: Icon(
            themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            color: const Color(0xFFCAD4E5),
          ),
        ),
      ),
      destinations: [
        for (final destination in _InventoryApplicationShellState._destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label.split(' ').first),
          ),
      ],
    );
  }
}

class _ExpandedBrand extends StatelessWidget {
  const _ExpandedBrand();
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _BrandMark(),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Inventory',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Stock Flow Optimization',
                style: TextStyle(color: Color(0xFF9FACC2), fontSize: 11),
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
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(11),
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

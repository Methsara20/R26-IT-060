// Final-polish pass: uses the shared page header and application card system.
import 'package:flutter/material.dart';

import '../../models/analytics/dashboard_command_center.dart';
import '../../models/analytics/dashboard_summary.dart';
import '../../services/analytics_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import 'widgets/attention_required_panel.dart';
import 'widgets/premium_dashboard_components.dart';
import '../../core/theme/application_design_tokens.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../core/widgets/application_feedback_components.dart';

/// Inventory decision command center backed by targeted aggregate documents.
class InventoryDecisionDashboardScreen extends StatefulWidget {
  const InventoryDecisionDashboardScreen({
    required this.onOpenInventoryIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovements,
    required this.onOpenAnalytics,
    super.key,
  });

  final VoidCallback onOpenInventoryIntelligence;
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovements;
  final VoidCallback onOpenAnalytics;

  @override
  State<InventoryDecisionDashboardScreen> createState() =>
      _InventoryDecisionDashboardScreenState();
}

class _InventoryDecisionDashboardScreenState
    extends State<InventoryDecisionDashboardScreen> {
  final _service = AnalyticsApiService();
  DashboardCommandCenter? _data;
  String? _error;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_refreshing || (_loading && refresh)) return;
    setState(() {
      _error = null;
      if (_data == null) {
        _loading = true;
      } else {
        _refreshing = true;
      }
    });
    try {
      final data = await _service.getDashboardCommandCenter();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
        _refreshing = false;
      });
    } on AnalyticsApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
        _refreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ApplicationPageContainer(
    maxWidth: 1400,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DashboardHeader(
          lastUpdated: _data?.summary.lastUpdated,
          refreshing: _refreshing,
          onRefresh: () => _load(refresh: true),
        ),
        const SizedBox(height: 26),
        if (_loading)
          const _DashboardLoadingState()
        else if (_data == null)
          _DashboardErrorState(
            message: _error ?? 'No dashboard summary is available.',
            onRetry: _load,
          )
        else ...[
          if (_error != null) ...[
            _RefreshWarning(message: _error!, onRetry: _load),
            const SizedBox(height: 18),
          ],
          _DashboardContent(
            data: _data!,
            onOpenInventoryIntelligence: widget.onOpenInventoryIntelligence,
            onOpenOptimization: widget.onOpenOptimization,
            onOpenMovements: widget.onOpenMovements,
            onOpenAnalytics: widget.onOpenAnalytics,
          ),
        ],
      ],
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.lastUpdated,
    required this.refreshing,
    required this.onRefresh,
  });
  final DateTime? lastUpdated;
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ApplicationPageHeader(
    premium: true,
    contextLabel: 'Inventory workspace',
    leadingIcon: Icons.dashboard_outlined,
    title: 'Dashboard',
    subtitle: 'Monitor inventory health, demand risk and stock-flow decisions',
    updatedText: 'Updated ${_updatedLabel(lastUpdated)}',
    onRefresh: onRefresh,
    refreshing: refreshing,
    refreshTooltip: 'Refresh dashboard',
  );
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.data,
    required this.onOpenInventoryIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovements,
    required this.onOpenAnalytics,
  });
  final DashboardCommandCenter data;
  final VoidCallback onOpenInventoryIntelligence;
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovements;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExecutiveInventoryOverview(
          lowStockCount: summary.lowStockItems,
          overstockCount: summary.overstockItems,
          onViewInventory: onOpenInventoryIntelligence,
          onReviewOptimization: onOpenOptimization,
        ),
        const SizedBox(height: 28),
        const _SectionHeading(
          title: 'Overall inventory position',
          subtitle: 'Current scale and capital held across the retail network',
        ),
        const SizedBox(height: 14),
        _PrimaryKpis(summary: summary),
        const SizedBox(height: 28),
        const _SectionHeading(
          title: 'Inventory health',
          subtitle:
              'Records currently crossing operational attention thresholds',
        ),
        const SizedBox(height: 14),
        _HealthSection(summary: summary),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final attention = _DashboardAlertSurface(
              child: AttentionRequiredPanel(
                lowStockItems: data.lowStockItems,
                overstockItems: data.overstockItems,
                onViewAll: onOpenInventoryIntelligence,
                onReview: onOpenInventoryIntelligence,
              ),
            );
            final decisions = _DecisionNavigationPanel(
              onOpenOptimization: onOpenOptimization,
              onOpenMovements: onOpenMovements,
            );
            if (constraints.maxWidth < 900) {
              return Column(
                children: [attention, const SizedBox(height: 18), decisions],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: attention),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: decisions),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        _FinancialOpportunityPanel(
          summary: summary,
          onOpenAnalytics: onOpenAnalytics,
        ),
      ],
    );
  }
}

class _PrimaryKpis extends StatelessWidget {
  const _PrimaryKpis({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => _ResponsiveGrid(
    largeColumns: 4,
    children: [
      PremiumDashboardMetric(
        label: 'Total products',
        value: _number(summary.totalProducts),
        caption: 'Active catalog items',
        icon: Icons.sell_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      PremiumDashboardMetric(
        label: 'Showrooms',
        value: _number(summary.totalStores),
        caption: 'Retail locations',
        icon: Icons.storefront_outlined,
        color: ApplicationColors.ai(context),
      ),
      PremiumDashboardMetric(
        label: 'Closing inventory',
        value: _compactNumber(summary.totalInventoryQuantity),
        caption: 'Across ${_number(summary.totalInventoryRecords)} records',
        icon: Icons.inventory_2_outlined,
        color: ApplicationColors.status(
          context,
          ApplicationStatusColor.success,
        ),
      ),
      PremiumDashboardMetric(
        label: 'Closing inventory value',
        value: _compactMoney(summary.totalInventoryValue),
        caption: _money(summary.totalInventoryValue),
        icon: Icons.account_balance_wallet_outlined,
        color: ApplicationColors.status(
          context,
          ApplicationStatusColor.warning,
        ),
      ),
    ],
  );
}

class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = Column(
        spacing: 16,
        children: [
          PremiumDashboardMetric(
            label: 'Low-stock records',
            value: _number(summary.lowStockItems),
            caption: 'At or below reorder level',
            icon: Icons.trending_down_rounded,
            color: ApplicationColors.status(
              context,
              ApplicationStatusColor.danger,
            ),
          ),
          PremiumDashboardMetric(
            label: 'Overstock records',
            value: _number(summary.overstockItems),
            caption: 'At or above the configured threshold',
            icon: Icons.inventory_outlined,
            color: ApplicationColors.status(
              context,
              ApplicationStatusColor.warning,
            ),
          ),
        ],
      );
      final profile = DashboardAttentionProfile(
        totalRecords: summary.totalInventoryRecords,
        lowStock: summary.lowStockItems,
        overstock: summary.overstockItems,
      );
      if (constraints.maxWidth < 820) {
        return Column(children: [cards, const SizedBox(height: 16), profile]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: cards),
          const SizedBox(width: 16),
          Expanded(child: profile),
        ],
      );
    },
  );
}

class _DecisionNavigationPanel extends StatelessWidget {
  const _DecisionNavigationPanel({
    required this.onOpenOptimization,
    required this.onOpenMovements,
  });
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovements;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock flow decisions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Open live decision modules for ranked candidates and '
            'backend-confirmed movement statuses.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _DecisionLink(
            icon: Icons.hub_outlined,
            title: 'Optimization workspace',
            subtitle: 'Review candidates and ranked source stores',
            onTap: onOpenOptimization,
          ),
          const SizedBox(height: 10),
          _DecisionLink(
            icon: Icons.swap_horiz,
            title: 'Stock movements',
            subtitle: 'Review and manage transfer decisions',
            onTap: onOpenMovements,
          ),
        ],
      ),
    ),
  );
}

class _DecisionLink extends StatelessWidget {
  const _DecisionLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(ApplicationRadii.card),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ApplicationRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 15),
          ],
        ),
      ),
    ),
  );
}

class _FinancialOpportunityPanel extends StatelessWidget {
  const _FinancialOpportunityPanel({
    required this.summary,
    required this.onOpenAnalytics,
  });
  final DashboardSummary summary;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory value & opportunity',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Potential values describe current inventory opportunity; '
                      'they are not guaranteed realized results.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onOpenAnalytics,
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Open analytics'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ResponsiveGrid(
            largeColumns: 3,
            children: [
              PremiumDashboardMetric(
                label: 'Inventory value',
                value: _compactMoney(summary.totalInventoryValue),
                caption: _money(summary.totalInventoryValue),
                icon: Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              PremiumDashboardMetric(
                label: 'Potential revenue',
                value: _compactMoney(summary.totalPotentialRevenue),
                caption: _money(summary.totalPotentialRevenue),
                icon: Icons.trending_up,
                color: ApplicationColors.status(
                  context,
                  ApplicationStatusColor.success,
                ),
              ),
              PremiumDashboardMetric(
                label: 'Potential profit',
                value: _compactMoney(summary.totalPotentialProfit),
                caption: _money(summary.totalPotentialProfit),
                icon: Icons.payments_outlined,
                color: ApplicationColors.status(
                  context,
                  ApplicationStatusColor.success,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.largeColumns});
  final List<Widget> children;
  final int largeColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1000
          ? largeColumns
          : constraints.maxWidth >= 620
          ? 2
          : 1;
      const spacing = 14.0;
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) =>
      ApplicationSectionHeader(title: title, subtitle: subtitle);
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const ApplicationLoadingSkeleton(height: 220),
      const SizedBox(height: 24),
      ApplicationResponsiveGrid(
        children: List.generate(
          4,
          (_) => const ApplicationSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ApplicationLoadingSkeleton(height: 20, width: 120),
                SizedBox(height: 20),
                ApplicationLoadingSkeleton(height: 36),
                SizedBox(height: 12),
                ApplicationLoadingSkeleton(height: 14),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ApplicationErrorState(
    title: 'Dashboard unavailable',
    message: message,
    onRetry: onRetry,
  );
}

class _RefreshWarning extends StatelessWidget {
  const _RefreshWarning({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => ApplicationInlineNotice(
    title: 'Dashboard refresh was unsuccessful',
    message: '$message The last successful data remains visible.',
    tone: ApplicationNoticeTone.warning,
    action: TextButton(onPressed: onRetry, child: const Text('Retry')),
  );
}

String _number(num value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

String _money(double value) => 'LKR ${_number(value)}';

String _compactNumber(num value) {
  if (value.abs() >= 1000000000) {
    return '${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return _number(value);
}

String _compactMoney(double value) {
  if (value.abs() >= 1000000000) {
    return 'LKR ${(value / 1000000000).toStringAsFixed(2)}B';
  }
  if (value.abs() >= 1000000) {
    return 'LKR ${(value / 1000000).toStringAsFixed(2)}M';
  }
  if (value.abs() >= 1000) {
    return 'LKR ${(value / 1000).toStringAsFixed(1)}K';
  }
  return _money(value);
}

String _updatedLabel(DateTime? value) {
  if (value == null) return 'Update time unavailable';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _DashboardAlertSurface extends StatelessWidget {
  const _DashboardAlertSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(ApplicationRadii.card),
      boxShadow: ApplicationElevation.forBrightness(
        Theme.of(context).brightness,
      ),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(
        cardTheme: Theme.of(context).cardTheme.copyWith(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ApplicationRadii.card),
            side: BorderSide(color: ApplicationColors.border(context)),
          ),
        ),
      ),
      child: child,
    ),
  );
}

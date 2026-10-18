// Final-polish pass: standardizes optimization filters and panel surfaces.
import 'package:flutter/material.dart';

import '../../core/theme/application_design_tokens.dart';
import '../../core/widgets/application_feedback_components.dart';
import '../../core/widgets/application_ui_components.dart';

import '../../models/optimization/optimization_candidate.dart';
import '../../models/stock_movement/stock_movement.dart';
import '../workflow/active_workflow_banner.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/workflow_progress_indicator.dart';

/// Single-column, progressive-disclosure workspace for optimization results.
class StockFlowDecisionWorkspace extends StatefulWidget {
  const StockFlowDecisionWorkspace({
    required this.overview,
    required this.analyzingId,
    required this.canAnalyze,
    required this.onAnalyze,
    super.key,
  });

  final OptimizationOverview overview;
  final String? analyzingId;
  final bool Function(OptimizationCandidate candidate) canAnalyze;
  final ValueChanged<OptimizationCandidate> onAnalyze;

  @override
  State<StockFlowDecisionWorkspace> createState() =>
      _StockFlowDecisionWorkspaceState();
}

class _StockFlowDecisionWorkspaceState
    extends State<StockFlowDecisionWorkspace> {
  final _searchController = TextEditingController();
  String _priority = 'ALL';
  String _action = 'ALL';
  String _showroom = 'ALL';

  int _currentPage = 0;
  static const int _pageSize = 5;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OptimizationCandidate> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    return widget.overview.candidates.where((candidate) {
      return (_priority == 'ALL' || candidate.priority == _priority) &&
          (_action == 'ALL' || candidate.recommendedAction == _action) &&
          (_showroom == 'ALL' || candidate.storeId == _showroom) &&
          (query.isEmpty ||
              candidate.productName.toLowerCase().contains(query) ||
              candidate.productId.toLowerCase().contains(query));
    }).toList();
  }

  List<String> get _actions {
    final values =
        widget.overview.candidates
            .map((item) => item.recommendedAction)
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  List<String> get _showrooms {
    final values =
        widget.overview.candidates.map((item) => item.storeId).toSet().toList()
          ..sort();
    return values;
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _priority != 'ALL' ||
      _action != 'ALL' ||
      _showroom != 'ALL';

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _priority = 'ALL';
      _action = 'ALL';
      _showroom = 'ALL';
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.overview.candidates;
    final unitsRequired = candidates
        .where((item) => item.shortageQuantity > 0)
        .fold<int>(0, (sum, item) => sum + item.shortageQuantity);
    final actionableTransfers = candidates
        .where((item) => item.hasActionableTransfer)
        .length;
    final filtered = _filtered;
    final int totalPages = (filtered.length / _pageSize).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize > filtered.length)
        ? filtered.length
        : startIndex + _pageSize;
    final paginated = filtered.isEmpty
        ? <OptimizationCandidate>[]
        : filtered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DecisionSummary(
          actionRequired: candidates.length,
          highPriority: widget.overview.summary.highPriority,
          unitsRequired: unitsRequired,
          recommendedTransfers: actionableTransfers,
        ),
        const SizedBox(height: 10),
        Text(
          '${candidates.length} inventory issue${candidates.length == 1 ? '' : 's'} require attention. '
          '${widget.overview.summary.highPriority} high priority. '
          '$actionableTransfers currently have backend-confirmed transfer options.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _FilterToolbar(
          searchController: _searchController,
          priority: _priority,
          action: _action,
          showroom: _showroom,
          actions: _actions,
          showrooms: _showrooms,
          resultCount: filtered.length,
          hasActiveFilters: _hasActiveFilters,
          onClear: _clearFilters,
          onSearchChanged: (_) => setState(() => _currentPage = 0),
          onPriorityChanged: (value) => setState(() {
            _priority = value;
            _currentPage = 0;
          }),
          onActionChanged: (value) => setState(() {
            _action = value;
            _currentPage = 0;
          }),
          onShowroomChanged: (value) => setState(() {
            _showroom = value;
            _currentPage = 0;
          }),
        ),
        const SizedBox(height: 20),
        Text('Priority queue', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 5),
        Text(
          '${filtered.length} decision${filtered.length == 1 ? '' : 's'} shown in backend order.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          _QueueEmpty(
            message: _hasActiveFilters
                ? 'No decisions match the selected filters.'
                : 'No optimization decisions require attention.',
            onReset: _hasActiveFilters ? _clearFilters : null,
          )
        else ...[
          for (final candidate in paginated) ...[
            OptimizationRecommendationCard(
              candidate: candidate,
              analyzing: widget.analyzingId == candidate.id,
              analysisDisabled: widget.analyzingId != null,
              analysisAllowed: widget.canAnalyze(candidate),
              onAnalyze: () => widget.onAnalyze(candidate),
            ),
            const SizedBox(height: 12),
          ],
          if (totalPages > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Page ${_currentPage + 1} of $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Focused rendering for the exact candidate/movement in the connected flow.
class ActiveStockFlowDecisionWorkspace extends StatelessWidget {
  const ActiveStockFlowDecisionWorkspace({
    required this.workflowController,
    required this.onOpenMovement,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenMovement;

  @override
  Widget build(BuildContext context) {
    final workflow = workflowController.current!;
    final candidate = workflow.candidate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActiveWorkflowBanner(workflow: workflow),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(ApplicationRadii.card),
            border: Border.all(color: ApplicationColors.border(context)),
          ),
          child: WorkflowProgressIndicator(
            currentStage: workflowController.currentStage,
            noReplenishmentRequired: workflow.status == 'NO_ACTION_REQUIRED',
          ),
        ),
        const SizedBox(height: 18),
        if (candidate == null)
          const _QueueEmpty(
            message:
                'This workflow requires no stock-flow optimization action.',
          )
        else
          OptimizationRecommendationCard(
            candidate: candidate,
            movement: workflow.movement,
            analyzing: false,
            analysisDisabled: true,
            analysisAllowed: false,
            onAnalyze: () {},
            onReviewTransfer: workflow.movement == null ? null : onOpenMovement,
          ),
      ],
    );
  }
}

class _DecisionSummary extends StatelessWidget {
  const _DecisionSummary({
    required this.actionRequired,
    required this.highPriority,
    required this.unitsRequired,
    required this.recommendedTransfers,
  });
  final int actionRequired;
  final int highPriority;
  final int unitsRequired;
  final int recommendedTransfers;

  @override
  Widget build(BuildContext context) {
    final information = ApplicationColors.status(
      context,
      ApplicationStatusColor.information,
    );
    final danger = ApplicationColors.status(
      context,
      ApplicationStatusColor.danger,
    );
    final warning = ApplicationColors.status(
      context,
      ApplicationStatusColor.warning,
    );
    final success = ApplicationColors.status(
      context,
      ApplicationStatusColor.success,
    );
    final values = [
      (
        'Action required',
        '$actionRequired',
        Icons.priority_high,
        information,
        'Open optimization decisions',
      ),
      (
        'High priority',
        '$highPriority',
        Icons.warning_amber_rounded,
        danger,
        'Decisions needing prompt review',
      ),
      (
        'Units required',
        '$unitsRequired',
        Icons.inventory_2_outlined,
        warning,
        'Total shortage across candidates',
      ),
      (
        'Recommended transfers',
        '$recommendedTransfers',
        Icons.swap_horiz,
        success,
        'Backend-confirmed transfer options',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 850
            ? 4
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: _SummaryTile(
                  label: item.$1,
                  value: item.$2,
                  icon: item.$3,
                  color: item.$4,
                  supportingText: item.$5,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.supportingText,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String supportingText;
  @override
  Widget build(BuildContext context) => ApplicationStatCard(
    label: label,
    value: value,
    icon: icon,
    accentColor: color,
    supportingText: supportingText,
    showAccentBar: true,
  );
}

class _FilterToolbar extends StatelessWidget {
  const _FilterToolbar({
    required this.searchController,
    required this.priority,
    required this.action,
    required this.showroom,
    required this.actions,
    required this.showrooms,
    required this.resultCount,
    required this.hasActiveFilters,
    required this.onClear,
    required this.onSearchChanged,
    required this.onPriorityChanged,
    required this.onActionChanged,
    required this.onShowroomChanged,
  });
  final TextEditingController searchController;
  final String priority;
  final String action;
  final String showroom;
  final List<String> actions;
  final List<String> showrooms;
  final int resultCount;
  final bool hasActiveFilters;
  final VoidCallback onClear;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onActionChanged;
  final ValueChanged<String> onShowroomChanged;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    padding: const EdgeInsets.all(ApplicationSpacing.medium),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ApplicationSpacing.compact,
          runSpacing: ApplicationSpacing.small,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Filter decision queue',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            ApplicationStatusBadge(
              label: '$resultCount result${resultCount == 1 ? '' : 's'}',
              tone: ApplicationStatusTone.info,
            ),
            if (hasActiveFilters)
              const ApplicationStatusBadge(
                label: 'Filters active',
                tone: ApplicationStatusTone.warning,
                icon: Icons.filter_alt_outlined,
              ),
          ],
        ),
        const SizedBox(height: ApplicationSpacing.compact),
        SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 850
                  ? 4
                  : constraints.maxWidth >= 480
                  ? 2
                  : 1;
              const gap = 10.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        labelText: 'Search products',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filter(
                      label: 'Priority',
                      value: priority,
                      options: const ['ALL', 'HIGH', 'MEDIUM', 'LOW'],
                      onChanged: onPriorityChanged,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filter(
                      label: 'Action',
                      value: action,
                      options: ['ALL', ...actions],
                      onChanged: onActionChanged,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _filter(
                      label: 'Showroom',
                      value: showroom,
                      options: ['ALL', ...showrooms],
                      onChanged: onShowroomChanged,
                    ),
                  ),
                  if (hasActiveFilters)
                    SizedBox(
                      width: width,
                      child: OutlinedButton.icon(
                        onPressed: onClear,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _filter({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final option in options)
        DropdownMenuItem(
          value: option,
          child: Text(
            option == 'ALL'
                ? 'All ${label.toLowerCase()}${label == 'Priority' ? ' levels' : 's'}'
                : _label(option),
          ),
        ),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

class OptimizationRecommendationCard extends StatelessWidget {
  const OptimizationRecommendationCard({
    required this.candidate,
    required this.analyzing,
    required this.analysisDisabled,
    required this.analysisAllowed,
    required this.onAnalyze,
    this.movement,
    this.onReviewTransfer,
    super.key,
  });

  final OptimizationCandidate candidate;
  final StockMovement? movement;
  final bool analyzing;
  final bool analysisDisabled;
  final bool analysisAllowed;
  final VoidCallback onAnalyze;
  final VoidCallback? onReviewTransfer;

  @override
  Widget build(BuildContext context) {
    final source = _bestCandidateSource(candidate, movement);
    final transferQuantity =
        movement?.recommendedQuantity ?? source?.possibleTransferQuantity ?? 0;
    final targetAfter =
        movement?.targetStockAfter ?? candidate.currentStock + transferQuantity;
    final canAnalyze = candidate.status == 'PENDING';
    final actionColor = candidate.priority == 'HIGH'
        ? ApplicationColors.status(context, ApplicationStatusColor.danger)
        : candidate.priority == 'MEDIUM'
        ? ApplicationColors.status(context, ApplicationStatusColor.warning)
        : ApplicationColors.status(context, ApplicationStatusColor.information);
    return ApplicationSurfaceCard(
      padding: const EdgeInsets.all(ApplicationSpacing.comfortable),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          label: '${_label(candidate.priority)} priority',
                          color: actionColor,
                        ),
                        _Badge(
                          label: _label(candidate.recommendedAction),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        _Badge(
                          label: _label(candidate.status),
                          color: _statusColor(context, candidate.status),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      candidate.productName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: ApplicationSpacing.medium,
                      runSpacing: ApplicationSpacing.xSmall,
                      children: [
                        _IdentityLabel(
                          icon: Icons.qr_code_2_outlined,
                          label: candidate.productId,
                        ),
                        _IdentityLabel(
                          icon: Icons.storefront_outlined,
                          label: 'Destination ${candidate.storeId}',
                        ),
                        _IdentityLabel(
                          icon: Icons.category_outlined,
                          label: candidate.category,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 30,
            runSpacing: 12,
            children: [
              _Value(label: 'Target condition', value: _label(candidate.type)),
              _Value(
                label: 'Current stock',
                value: '${candidate.currentStock} units',
              ),
              _Value(
                label: 'Reorder level',
                value: '${candidate.reorderLevel} units',
              ),
              _Value(
                label: candidate.type == 'LOW_STOCK' ? 'Shortage' : 'Surplus',
                value:
                    '${candidate.type == 'LOW_STOCK' ? candidate.shortageQuantity : candidate.surplusQuantity} units',
              ),
            ],
          ),
          if (candidate.hasInconsistentTransferDecision) ...[
            const SizedBox(height: 16),
            const _SafetyWarning(),
          ],
          if (source != null && transferQuantity > 0) ...[
            const SizedBox(height: 18),
            _MovementPreview(
              candidate: candidate,
              movement: movement,
              source: source,
              transferQuantity: transferQuantity,
              targetAfter: targetAfter,
            ),
          ],
          const SizedBox(height: 14),
          ApplicationAiPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: const Text(
                'Why this decision?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    candidate.decisionReason.isEmpty
                        ? 'No detailed decision explanation was returned.'
                        : candidate.decisionReason,
                  ),
                ),
                if (candidate.decisionConfidence != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Decision confidence: ${candidate.decisionConfidence}%',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_alternativeCount(candidate, movement) > 0)
            Material(
              color: Colors.transparent,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(
                  'Alternative sources (${_alternativeCount(candidate, movement)})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                children: _alternativeWidgets(candidate, movement),
              ),
            ),
          if ((canAnalyze && analysisAllowed) || onReviewTransfer != null) ...[
            const SizedBox(height: ApplicationSpacing.compact),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: ApplicationSpacing.small,
              runSpacing: ApplicationSpacing.small,
              children: [
                if (canAnalyze && analysisAllowed)
                  FilledButton.icon(
                    onPressed: analysisDisabled ? null : onAnalyze,
                    icon: analyzing
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(analyzing ? 'Analyzing…' : 'Analyze candidate'),
                  ),
                if (onReviewTransfer != null)
                  FilledButton.tonalIcon(
                    onPressed: onReviewTransfer,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Review transfer'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityLabel extends StatelessWidget {
  const _IdentityLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );
}

class _MovementPreview extends StatelessWidget {
  const _MovementPreview({
    required this.candidate,
    required this.movement,
    required this.source,
    required this.transferQuantity,
    required this.targetAfter,
  });
  final OptimizationCandidate candidate;
  final StockMovement? movement;
  final QualifiedSourceStore source;
  final int transferQuantity;
  final int targetAfter;

  @override
  Widget build(BuildContext context) {
    final sourceBefore = movement?.sourceStockBefore ?? source.currentStock;
    final sourceAfter = movement?.sourceStockAfter ?? source.stockAfterTransfer;
    final targetBefore = movement?.targetStockBefore ?? candidate.currentStock;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(ApplicationRadii.card),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended stock movement',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              final children = [
                _StorePosition(
                  label: 'FROM',
                  store: movement?.fromStore ?? source.storeId,
                  stock: '$sourceBefore units',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        narrow ? Icons.arrow_downward : Icons.arrow_forward,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      Text(
                        '$transferQuantity units',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                _StorePosition(
                  label: 'TO',
                  store: movement?.toStore ?? candidate.storeId,
                  stock: '$targetBefore units',
                ),
              ];
              return Flex(
                direction: narrow ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: children,
              );
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              Text(
                'Source after: $sourceBefore -> $sourceAfter',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                'Target after: $targetBefore -> $targetAfter',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (movement != null)
                Text(
                  '${movement!.coveragePercentage.toStringAsFixed(0)}% shortage covered',
                  style: TextStyle(
                    color: ApplicationColors.status(
                      context,
                      ApplicationStatusColor.success,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (movement != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                Text('${movement!.distanceKm.toStringAsFixed(1)} km'),
                Text('${movement!.estimatedTimeMinutes} min'),
                Text(
                  'LKR ${movement!.estimatedTransferCost.toStringAsFixed(2)}',
                ),
                Text('${movement!.confidence.toStringAsFixed(0)}% confidence'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StorePosition extends StatelessWidget {
  const _StorePosition({
    required this.label,
    required this.store,
    required this.stock,
  });
  final String label;
  final String store;
  final String stock;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(store, style: Theme.of(context).textTheme.titleMedium),
      Text(stock),
    ],
  );
}

QualifiedSourceStore? _bestCandidateSource(
  OptimizationCandidate candidate,
  StockMovement? movement,
) {
  final actionable = candidate.actionableSources;
  if (actionable.isEmpty) return null;
  if (movement != null) {
    for (final source in actionable) {
      if (source.storeId == movement.fromStore) return source;
    }
  }
  return actionable.first;
}

int _alternativeCount(
  OptimizationCandidate candidate,
  StockMovement? movement,
) => movement != null && movement.evaluatedSources.isNotEmpty
    ? movement.evaluatedSources
          .where((source) => source.storeId != movement.fromStore)
          .length
    : (candidate.actionableSources.length - 1).clamp(
        0,
        candidate.actionableSources.length,
      );

List<Widget> _alternativeWidgets(
  OptimizationCandidate candidate,
  StockMovement? movement,
) {
  if (movement != null && movement.evaluatedSources.isNotEmpty) {
    return [
      for (final source in movement.evaluatedSources.where(
        (item) => item.storeId != movement.fromStore,
      ))
        _AlternativeRow(
          rank: source.rank,
          store: source.storeId,
          quantity: source.safeTransferQuantity,
          remaining: source.remainingBuffer,
          distance: source.distanceKm,
          cost: source.estimatedTransferCost,
        ),
    ];
  }
  final sources = candidate.actionableSources.skip(1).toList();
  return [
    for (var index = 0; index < sources.length; index++)
      _AlternativeRow(
        rank: index + 2,
        store: sources[index].storeId,
        quantity: sources[index].possibleTransferQuantity,
        remaining: sources[index].stockAfterTransfer,
      ),
  ];
}

class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({
    required this.rank,
    required this.store,
    required this.quantity,
    required this.remaining,
    this.distance,
    this.cost,
  });
  final int rank;
  final String store;
  final int quantity;
  final int remaining;
  final double? distance;
  final double? cost;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: ApplicationColors.panelMuted(context),
      borderRadius: BorderRadius.circular(ApplicationRadii.control),
      border: Border.all(color: ApplicationColors.border(context)),
    ),
    child: Wrap(
      spacing: 22,
      runSpacing: 6,
      children: [
        Text(
          '#$rank $store',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text('Transferable: $quantity'),
        Text('Remaining: $remaining'),
        if (distance != null) Text('${distance!.toStringAsFixed(1)} km'),
        if (cost != null) Text('LKR ${cost!.toStringAsFixed(2)}'),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) =>
      ApplicationStatusBadge(label: label, color: color);
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 120, maxWidth: 180),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _SafetyWarning extends StatelessWidget {
  const _SafetyWarning();
  @override
  Widget build(BuildContext context) => const ApplicationInlineNotice(
    title: 'Decision requires review',
    message:
        'This transfer decision has no positive shortage or safe transfer quantity. Review the backend result before proceeding.',
    tone: ApplicationNoticeTone.danger,
  );
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({
    this.message = 'No decisions match the selected filters.',
    this.onReset,
  });
  final String message;
  final VoidCallback? onReset;
  @override
  Widget build(BuildContext context) => ApplicationEmptyState(
    icon: Icons.tune_outlined,
    title: onReset == null ? 'Queue is clear' : 'No matching decisions',
    message: message,
    action: onReset == null
        ? null
        : OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Reset filters'),
          ),
  );
}

Color _statusColor(BuildContext context, String status) => switch (status) {
  'RECOMMENDED' || 'COMPLETED' => ApplicationColors.status(
    context,
    ApplicationStatusColor.success,
  ),
  'PENDING' || 'PROCESSING' => ApplicationColors.status(
    context,
    ApplicationStatusColor.warning,
  ),
  'FAILED' || 'REJECTED' => ApplicationColors.status(
    context,
    ApplicationStatusColor.danger,
  ),
  _ => Theme.of(context).colorScheme.onSurfaceVariant,
};

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

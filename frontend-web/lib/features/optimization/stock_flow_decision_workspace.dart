// Final-polish pass: standardizes optimization filters and panel surfaces.
import 'package:flutter/material.dart';

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
    required this.onAnalyze,
    super.key,
  });

  final OptimizationOverview overview;
  final String? analyzingId;
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
          onSearchChanged: (_) => setState(() {}),
          onPriorityChanged: (value) => setState(() => _priority = value),
          onActionChanged: (value) => setState(() => _action = value),
          onShowroomChanged: (value) => setState(() => _showroom = value),
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
          const _QueueEmpty()
        else
          for (final candidate in filtered) ...[
            OptimizationRecommendationCard(
              candidate: candidate,
              analyzing: widget.analyzingId == candidate.id,
              analysisDisabled: widget.analyzingId != null,
              onAnalyze: () => widget.onAnalyze(candidate),
            ),
            const SizedBox(height: 12),
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE1E7F0)),
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
    final values = [
      (
        'Action required',
        '$actionRequired',
        Icons.priority_high,
        const Color(0xFF155EEF),
      ),
      (
        'High priority',
        '$highPriority',
        Icons.warning_amber_rounded,
        const Color(0xFFD92D20),
      ),
      (
        'Units required',
        '$unitsRequired',
        Icons.inventory_2_outlined,
        const Color(0xFFDC6803),
      ),
      (
        'Recommended transfers',
        '$recommendedTransfers',
        Icons.swap_horiz,
        const Color(0xFF17875D),
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
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => ApplicationStatCard(
    label: label,
    value: value,
    icon: icon,
    accentColor: color,
    showAccentBar: false,
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
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onActionChanged;
  final ValueChanged<String> onShowroomChanged;

  @override
  Widget build(BuildContext context) => ApplicationFilterBar(
    children: [
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
              ],
            );
          },
        ),
      ),
    ],
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
    required this.onAnalyze,
    this.movement,
    this.onReviewTransfer,
    super.key,
  });

  final OptimizationCandidate candidate;
  final StockMovement? movement;
  final bool analyzing;
  final bool analysisDisabled;
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
        ? const Color(0xFFD92D20)
        : const Color(0xFFDC6803);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
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
                          color: const Color(0xFF155EEF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      candidate.productName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${candidate.productId} | ${candidate.storeId} | ${candidate.category}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (canAnalyze)
                FilledButton.icon(
                  onPressed: analysisDisabled ? null : onAnalyze,
                  icon: analyzing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_outlined),
                  label: Text(analyzing ? 'Analyzing...' : 'Analyze'),
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
          if (onReviewTransfer != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onReviewTransfer,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review transfer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
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
        color: const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(12),
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
              final narrow = constraints.maxWidth < 560;
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
                      const Icon(Icons.arrow_forward, color: Color(0xFF155EEF)),
                      Text(
                        '$transferQuantity units',
                        style: const TextStyle(
                          color: Color(0xFF155EEF),
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
                  style: const TextStyle(
                    color: Color(0xFF17875D),
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
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(9),
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
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF1F0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: Color(0xFFD92D20)),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'This transfer decision has no positive shortage or safe transfer quantity. Review the backend result before proceeding.',
          ),
        ),
      ],
    ),
  );
}

class _QueueEmpty extends StatelessWidget {
  const _QueueEmpty({
    this.message = 'No decisions match the selected filters.',
  });
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(34),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE1E7F0)),
    ),
    child: Center(child: Text(message)),
  );
}

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

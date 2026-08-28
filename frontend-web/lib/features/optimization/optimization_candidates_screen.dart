// Final-polish pass: standardizes the header, filters, and semantic badges.
// Legacy presentation widgets remain in this file temporarily as a verified
// fallback while the extracted decision workspace is reviewed.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import '../../models/optimization/optimization_candidate.dart';
import '../../models/stock_movement/stock_movement.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../../services/optimization_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import 'stock_flow_decision_workspace.dart';

/// Decision-support workspace for stored optimization candidates.
class OptimizationCandidatesScreen extends StatefulWidget {
  const OptimizationCandidatesScreen({
    required this.workflowController,
    required this.onOpenMovement,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenMovement;
  @override
  State<OptimizationCandidatesScreen> createState() =>
      _OptimizationCandidatesScreenState();
}

class _OptimizationCandidatesScreenState
    extends State<OptimizationCandidatesScreen> {
  final _service = OptimizationApiService();
  Future<OptimizationOverview>? _overviewFuture;
  String? _analyzingId;
  bool _showWorkflowRecommendation = false;

  @override
  void initState() {
    super.initState();
    // The queue remains the default even while global workflow context exists.
    _overviewFuture = _service.getOverview();
  }

  void _reload() => setState(() => _overviewFuture = _service.getOverview());

  Future<void> _analyze(OptimizationCandidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analyze candidate?'),
        content: Text(
          'Run the decision engine for ${candidate.productName} at ${candidate.storeId}? The candidate status will be updated by the backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Analyze'),
          ),
        ],
      ),
    );
    if (confirmed != true || _analyzingId != null) return;
    setState(() => _analyzingId = candidate.id);
    try {
      final updated = await _service.analyzeCandidate(candidate.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Decision confirmed: ${updated.recommendedAction} (${updated.decisionConfidence ?? 0}% confidence).',
          ),
        ),
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _analyzingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflow = widget.workflowController.current;
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ApplicationPageHeader(
            title: 'Optimization',
            subtitle:
                'Review prioritized stock-flow decisions and recommended actions',
            actions: [
              IconButton.filledTonal(
                onPressed: _reload,
                tooltip: 'Refresh candidates',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (workflow?.candidate != null && _showWorkflowRecommendation) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _showWorkflowRecommendation = false),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to optimization queue'),
              ),
            ),
            const SizedBox(height: 14),
            _ActiveWorkflowOptimization(
              workflowController: widget.workflowController,
              onOpenMovement: widget.onOpenMovement,
            ),
          ] else ...[
            if (workflow?.candidate != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome_outlined),
                      Text(
                        'Active workflow recommendation available for '
                        '${workflow!.productId} at ${workflow.storeId}.',
                      ),
                      TextButton(
                        onPressed:
                            widget.workflowController.clearActiveWorkflow,
                        child: const Text('Clear workflow'),
                      ),
                      FilledButton.tonal(
                        onPressed: () =>
                            setState(() => _showWorkflowRecommendation = true),
                        child: const Text('Open recommendation'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            FutureBuilder<OptimizationOverview>(
              future: _overviewFuture!,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _OptimizationLoading();
                }
                if (snapshot.hasError) {
                  return _OptimizationError(
                    message: snapshot.error.toString(),
                    onRetry: _reload,
                  );
                }
                final overview = snapshot.data!;
                return StockFlowDecisionWorkspace(
                  overview: overview,
                  analyzingId: _analyzingId,
                  onAnalyze: _analyze,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Focuses the exact candidate returned by the active connected workflow.
class _ActiveWorkflowOptimization extends StatelessWidget {
  const _ActiveWorkflowOptimization({
    required this.workflowController,
    required this.onOpenMovement,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenMovement;

  @override
  Widget build(BuildContext context) {
    return ActiveStockFlowDecisionWorkspace(
      workflowController: workflowController,
      onOpenMovement: onOpenMovement,
    );
  }
}

class _RankedSourceAnalysis extends StatelessWidget {
  const _RankedSourceAnalysis({
    required this.movement,
    required this.onOpenMovement,
  });

  final StockMovement movement;
  final VoidCallback onOpenMovement;

  @override
  Widget build(BuildContext context) {
    final sources = movement.evaluatedSources;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ranked source analysis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              movement.recommendationReason ??
                  'Backend-ranked transfer sources.',
            ),
            const SizedBox(height: 16),
            if (sources.isEmpty)
              const Text('No detailed source alternatives were returned.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 760 ? 2 : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final source in sources)
                        SizedBox(
                          width: width,
                          child: _SourceOptionCard(
                            source: source,
                            recommended: source.storeId == movement.fromStore,
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onOpenMovement,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Review recommendation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceOptionCard extends StatelessWidget {
  const _SourceOptionCard({required this.source, required this.recommended});

  final MovementSourceAlternative source;
  final bool recommended;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: recommended ? const Color(0xFFECFDF3) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: recommended ? const Color(0xFF6CE9A6) : const Color(0xFFE4E8F0),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  source.storeId,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (recommended)
                const Chip(label: Text('Recommended source'))
              else
                Chip(label: Text('Alternative #${source.rank}')),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _Value(
                label: 'Safe quantity',
                value: '${source.safeTransferQuantity}',
              ),
              _Value(label: 'Surplus', value: '${source.surplusQuantity}'),
              _Value(
                label: 'Remaining buffer',
                value: '${source.remainingBuffer}',
              ),
              _Value(
                label: 'Distance',
                value: '${source.distanceKm.toStringAsFixed(1)} km',
              ),
              _Value(
                label: 'Travel time',
                value: '${source.estimatedTimeMinutes} min',
              ),
              _Value(
                label: 'Transfer cost',
                value: 'LKR ${source.estimatedTransferCost.toStringAsFixed(2)}',
              ),
              _Value(
                label: 'Coverage',
                value: '${source.coveragePercentage.toStringAsFixed(0)}%',
              ),
              _Value(label: 'Risk', value: source.riskAfterTransfer),
            ],
          ),
        ],
      ),
    ),
  );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final OptimizationSummary summary;
  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Candidates',
        summary.total,
        Icons.hub_outlined,
        const Color(0xFF155EEF),
      ),
      (
        'High priority',
        summary.highPriority,
        Icons.priority_high,
        const Color(0xFFD92D20),
      ),
      (
        'Low stock',
        summary.lowStock,
        Icons.trending_down,
        const Color(0xFFF79009),
      ),
      (
        'Overstock',
        summary.overstock,
        Icons.inventory_outlined,
        const Color(0xFF7A5AF8),
      ),
      ('Pending', summary.pending, Icons.schedule, const Color(0xFF475467)),
      (
        'Recommended',
        summary.recommended,
        Icons.recommend_outlined,
        const Color(0xFF039855),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.$4.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(item.$3, color: item.$4),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${item.$2}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.priority,
    required this.type,
    required this.onPriorityChanged,
    required this.onTypeChanged,
  });
  final String priority;
  final String type;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onTypeChanged;
  @override
  Widget build(BuildContext context) => ApplicationFilterBar(
    children: [
      ApplicationFilterDropdown(
        label: 'Priority',
        value: priority,
        items: const {
          'ALL': 'All priorities',
          'HIGH': 'High',
          'MEDIUM': 'Medium',
          'LOW': 'Low',
        },
        onChanged: onPriorityChanged,
      ),
      ApplicationFilterDropdown(
        label: 'Candidate type',
        value: type,
        items: const {
          'ALL': 'All types',
          'LOW_STOCK': 'Low stock',
          'OVERSTOCK': 'Overstock',
        },
        onChanged: onTypeChanged,
      ),
    ],
  );
}

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.candidate,
    required this.analyzing,
    required this.analysisDisabled,
    required this.onAnalyze,
  });
  final OptimizationCandidate candidate;
  final bool analyzing;
  final bool analysisDisabled;
  final VoidCallback onAnalyze;
  @override
  Widget build(BuildContext context) {
    final canAnalyze = candidate.status == 'PENDING';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      Text(
                        candidate.productName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate.productId} • ${candidate.storeId} • ${candidate.category}',
                      ),
                    ],
                  ),
                ),
                _Badge(
                  label: candidate.priority,
                  color: candidate.priority == 'HIGH'
                      ? const Color(0xFFD92D20)
                      : const Color(0xFFF79009),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _Value(label: 'Stock', value: '${candidate.currentStock}'),
                _Value(label: 'Reorder', value: '${candidate.reorderLevel}'),
                _Value(label: 'Maximum', value: '${candidate.maxStock}'),
                _Value(
                  label: candidate.type == 'LOW_STOCK' ? 'Shortage' : 'Surplus',
                  value:
                      '${candidate.type == 'LOW_STOCK' ? candidate.shortageQuantity : candidate.surplusQuantity}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge(
                  label: candidate.type.replaceAll('_', ' '),
                  color: const Color(0xFF155EEF),
                ),
                _Badge(
                  label: candidate.stockHealth,
                  color: const Color(0xFF7A5AF8),
                ),
                _Badge(
                  label: candidate.status,
                  color: candidate.status == 'RECOMMENDED'
                      ? const Color(0xFF039855)
                      : const Color(0xFF475467),
                ),
              ],
            ),
            if (candidate.status == 'RECOMMENDED') ...[
              const Divider(height: 28),
              if (candidate.hasInconsistentTransferDecision)
                const _DecisionSafetyWarning()
              else ...[
                Text(
                  candidate.recommendedAction,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (candidate.decisionConfidence != null)
                  Text('${candidate.decisionConfidence}% decision confidence'),
                if (candidate.decisionReason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(candidate.decisionReason),
                  ),
                if (candidate.transferFeasibility != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Transfer feasibility: ${candidate.transferFeasibility} • Coverage: ${candidate.coverageRatio ?? 0}×',
                    ),
                  ),
              ],
              if (candidate.actionableSources.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Qualified source stores',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                for (final source in candidate.actionableSources)
                  Text(
                    '${source.storeId}: transfer up to ${source.possibleTransferQuantity}, remaining stock ${source.stockAfterTransfer}',
                  ),
              ],
            ],
            if (canAnalyze) ...[
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: analysisDisabled ? null : onAnalyze,
                  icon: analyzing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.psychology_outlined),
                  label: Text(analyzing ? 'Analyzing…' : 'Analyze candidate'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DecisionSafetyWarning extends StatelessWidget {
  const _DecisionSafetyWarning();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Decision requires review. The backend recommended a transfer without a positive shortage or transfer quantity. No stock movement should be created from this recommendation.',
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

class _OptimizationLoading extends StatelessWidget {
  const _OptimizationLoading();
  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _OptimizationEmpty extends StatelessWidget {
  const _OptimizationEmpty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 40,
              color: Color(0xFF039855),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class _OptimizationError extends StatelessWidget {
  const _OptimizationError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

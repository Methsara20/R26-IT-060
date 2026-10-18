// AI explanations use the reserved shared AI surface treatment.
import 'package:flutter/material.dart';

import '../../core/theme/application_design_tokens.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../models/workflow/decision_workflow.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/workflow_progress_indicator.dart';

/// Manager-first presentation of the backend-owned connected decision.
class ForecastInventoryDecisionPanel extends StatelessWidget {
  const ForecastInventoryDecisionPanel({
    required this.workflow,
    required this.onOpenIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovement,
    required this.onAskAssistant,
    super.key,
  });

  final DecisionWorkflow workflow;
  final VoidCallback onOpenIntelligence;
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovement;
  final VoidCallback onAskAssistant;

  bool get _noAction => workflow.status == 'NO_ACTION_REQUIRED';
  bool get _executed => workflow.movement?.status == 'EXECUTED';

  @override
  Widget build(BuildContext context) {
    final intelligence = workflow.intelligence;
    final shortage = workflow.safetyStockShortage;
    final action = intelligence?.operationalAction ?? workflow.nextAction;
    final title = _executed
        ? 'Transfer completed'
        : _noAction
        ? 'No replenishment required'
        : _label(action);
    final accent = _executed || _noAction
        ? const Color(0xFF17875D)
        : shortage > 0
        ? const Color(0xFFD97706)
        : Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inventory decision',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1E7F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_noAction && !_executed && shortage > 0)
                    Text(
                      '$shortage units required to maintain safety stock',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              if (_executed)
                _ExecutedSummary(workflow: workflow)
              else
                _DecisionMetrics(workflow: workflow),
              const SizedBox(height: 18),
              WorkflowProgressIndicator(
                currentStage: WorkflowStage.fromWorkflow(workflow),
                noReplenishmentRequired: _noAction,
              ),
              if (intelligence?.operationalReason.isNotEmpty == true) ...[
                const SizedBox(height: 18),
                ApplicationAiPanel(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: ApplicationColors.ai(context),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Why this action?',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              intelligence!.operationalReason,
                              style: const TextStyle(height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (workflow.candidate != null) ...[
                const SizedBox(height: 18),
                _OptimizationSummary(workflow: workflow),
              ],
              const SizedBox(height: 18),
              _Actions(
                workflow: workflow,
                onOpenIntelligence: onOpenIntelligence,
                onOpenOptimization: onOpenOptimization,
                onOpenMovement: onOpenMovement,
                onAskAssistant: onAskAssistant,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionMetrics extends StatelessWidget {
  const _DecisionMetrics({required this.workflow});
  final DecisionWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final intelligence = workflow.intelligence;
    final metrics = [
      ('Current stock', '${workflow.currentStock} units'),
      ('Forecast demand', '${intelligence?.forecastDemand ?? 0} units'),
      (
        'Projected stock',
        '${workflow.projectedStock.toStringAsFixed(0)} units',
      ),
      ('Reorder level', '${workflow.reorderLevel} units'),
      ('Required stock', '${workflow.requiredStock.toStringAsFixed(0)} units'),
      ('Safety-stock shortage', '${workflow.safetyStockShortage} units'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 28,
          runSpacing: 16,
          children: [
            for (final metric in metrics)
              _Metric(label: metric.$1, value: metric.$2),
          ],
        ),
        if (intelligence != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              Text('Forecast-demand health: ${intelligence.stockHealth}'),
              Text('Stockout risk: ${intelligence.stockoutRisk}'),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExecutedSummary extends StatelessWidget {
  const _ExecutedSummary({required this.workflow});
  final DecisionWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final movement = workflow.movement!;
    return Wrap(
      spacing: 28,
      runSpacing: 16,
      children: [
        _Metric(label: 'Source', value: movement.fromStore),
        _Metric(label: 'Destination', value: movement.toStore),
        _Metric(
          label: 'Quantity',
          value: '${movement.recommendedQuantity} units',
        ),
        _Metric(label: 'Status', value: _label(movement.status)),
      ],
    );
  }
}

class _OptimizationSummary extends StatelessWidget {
  const _OptimizationSummary({required this.workflow});
  final DecisionWorkflow workflow;

  @override
  Widget build(BuildContext context) {
    final candidate = workflow.candidate!;
    final surplus = candidate.sources.fold<int>(
      0,
      (sum, source) => sum + source.surplusQuantity,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Optimization available',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 28,
            runSpacing: 14,
            children: [
              _Metric(
                label: 'Qualified sources',
                value: '${candidate.sources.length}',
              ),
              _Metric(label: 'Qualified surplus', value: '$surplus units'),
              _Metric(
                label: 'Required transfer',
                value: '${workflow.safetyStockShortage} units',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 130, maxWidth: 190),
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

class _Actions extends StatelessWidget {
  const _Actions({
    required this.workflow,
    required this.onOpenIntelligence,
    required this.onOpenOptimization,
    required this.onOpenMovement,
    required this.onAskAssistant,
  });
  final DecisionWorkflow workflow;
  final VoidCallback onOpenIntelligence;
  final VoidCallback onOpenOptimization;
  final VoidCallback onOpenMovement;
  final VoidCallback onAskAssistant;

  @override
  Widget build(BuildContext context) {
    final hasMovement = workflow.movement != null;
    final executed = workflow.movement?.status == 'EXECUTED';
    final primaryCallback = hasMovement
        ? onOpenMovement
        : workflow.candidate != null
        ? onOpenOptimization
        : onOpenIntelligence;
    final primaryLabel = executed
        ? 'View movement'
        : hasMovement
        ? 'Review recommendation'
        : workflow.candidate != null
        ? 'Review optimization'
        : 'View inventory intelligence';
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: primaryCallback,
          icon: Icon(executed ? Icons.swap_horiz : Icons.fact_check_outlined),
          label: Text(primaryLabel),
        ),
        if (workflow.candidate != null && hasMovement)
          TextButton(
            onPressed: onOpenOptimization,
            child: const Text('Review optimization'),
          ),
        if (hasMovement || workflow.candidate != null)
          TextButton(
            onPressed: onOpenIntelligence,
            child: const Text('View intelligence'),
          ),
        TextButton.icon(
          onPressed: onAskAssistant,
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: const Text('Ask assistant'),
        ),
      ],
    );
  }
}

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

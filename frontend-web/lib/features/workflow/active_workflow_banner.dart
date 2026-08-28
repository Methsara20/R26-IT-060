// Workflow identity uses shared AI and telemetry typography primitives.
import 'package:flutter/material.dart';

import '../../core/widgets/application_ui_components.dart';
import '../../models/workflow/decision_workflow.dart';

/// Compact identity banner shared by workflow-aware module screens.
class ActiveWorkflowBanner extends StatelessWidget {
  const ActiveWorkflowBanner({required this.workflow, super.key});

  final DecisionWorkflow workflow;


  @override
  Widget build(BuildContext context) {
    return ApplicationAiPanel(
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.account_tree_outlined),
          _BannerValue(label: 'Workflow', value: workflow.id),
          _BannerValue(label: 'Showroom', value: workflow.storeId),
          _BannerValue(label: 'Product', value: workflow.productId),
          _BannerValue(label: 'Forecast', value: _label(workflow.forecastType)),
          _BannerValue(label: 'Status', value: _label(workflow.status)),
        ],
      ),
    );
  }
}

class _BannerValue extends StatelessWidget {
  const _BannerValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 110, maxWidth: 230),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        ApplicationDataText(
          value,
          overflow: TextOverflow.ellipsis,
          fontWeight: FontWeight.w700,
        ),
      ],
    ),
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

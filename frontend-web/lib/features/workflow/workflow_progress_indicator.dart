import 'package:flutter/material.dart';

import 'inventory_decision_workflow_controller.dart';

/// Displays the shared manager workflow without issuing network requests.
class WorkflowProgressIndicator extends StatelessWidget {
  const WorkflowProgressIndicator({
    required this.currentStage,
    this.noReplenishmentRequired = false,
    super.key,
  });

  final WorkflowStage currentStage;
  final bool noReplenishmentRequired;

  static const _labels = <String>[
    'Forecast',
    'Intelligence',
    'Optimization',
    'Review',
    'Execution',
    'Completed',
  ];


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < _labels.length; index++) ...[
            _StageChip(
              label: _labels[index],
              completed: noReplenishmentRequired
                  ? index <= WorkflowStage.intelligence.index
                  : currentStage == WorkflowStage.completed
                  ? index <= currentStage.index
                  : index < currentStage.index,
              active:
                  !noReplenishmentRequired &&
                  currentStage != WorkflowStage.completed &&
                  index == currentStage.index,
              skipped:
                  noReplenishmentRequired &&
                  index > WorkflowStage.intelligence.index,
            ),
            if (index < _labels.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF8290A8),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({
    required this.label,
    required this.completed,
    required this.active,
    required this.skipped,
  });

  final String label;
  final bool completed;
  final bool active;
  final bool skipped;

  @override
  Widget build(BuildContext context) {
    final color = skipped
        ? const Color(0xFF8290A8)
        : active
        ? Theme.of(context).colorScheme.primary
        : completed
        ? const Color(0xFF287A55)
        : const Color(0xFF8290A8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed
                ? Icons.check_circle
                : skipped
                ? Icons.remove_circle_outline
                : active
                ? Icons.radio_button_checked
                : Icons.circle_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: active || completed
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

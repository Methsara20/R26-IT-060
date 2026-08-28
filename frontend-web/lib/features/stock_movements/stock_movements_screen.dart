// Final-polish pass: standardizes the page header and live-data utility action.
// Legacy list widgets remain below as a verified rollback reference while the
// operational workspace is validated in the full application.
// ignore_for_file: unused_element

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/stock_movement/stock_movement.dart';
import '../../services/stock_movement_api_service.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import '../workflow/inventory_decision_workflow_controller.dart';
import '../workflow/active_workflow_banner.dart';
import '../workflow/workflow_progress_indicator.dart';
import 'stock_movement_workspace.dart';

class StockMovementsScreen extends StatefulWidget {
  const StockMovementsScreen({
    required this.workflowController,
    required this.onOpenAnalytics,
    required this.onAskAssistant,
    super.key,
  });

  final InventoryDecisionWorkflowController workflowController;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onAskAssistant;

  @override
  State<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends State<StockMovementsScreen> {
  final _api = StockMovementApiService();
  List<StockMovement> _movements = const [];
  String? _error;
  String? _busyMovementId;
  String? _verificationPendingId;
  bool _generatingReplacement = false;
  bool _loading = true;
  bool _showWorkflowMovement = false;

  @override
  void initState() {
    super.initState();
    // Stored movement records are always the page's default content.
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final movements = await _api.getMovements();
      if (!mounted) return;
      setState(() {
        _movements = movements;
        _loading = false;
      });
    } on StockMovementApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _openHistory() async {
    setState(() => _showWorkflowMovement = false);
  }

  Future<void> _performAction(
    StockMovement movement,
    _MovementAction action,
  ) async {
    final reasonController = TextEditingController();
    final needsReason =
        action == _MovementAction.reject || action == _MovementAction.cancel;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${action.label} movement?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${movement.recommendedQuantity} units of '
              '${movement.productName} will be affected.',
            ),
            if (action == _MovementAction.execute) ...[
              const SizedBox(height: 12),
              const Text(
                'Execution updates source and target inventory. This action '
                'should only be confirmed after operational review.',
              ),
            ],
            if (needsReason) ...[
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: action == _MovementAction.reject
                      ? 'Rejection reason (optional)'
                      : 'Cancellation reason (optional)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Confirm ${action.label.toLowerCase()}'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _busyMovementId = movement.movementId);
    try {
      final updated = switch (action) {
        _MovementAction.approve => _api.approve(movement.movementId),
        _MovementAction.reject => _api.reject(
          movement.movementId,
          reason.isEmpty ? null : reason,
        ),
        _MovementAction.cancel => _api.cancel(
          movement.movementId,
          reason.isEmpty ? null : reason,
        ),
        _MovementAction.execute => _api.execute(movement.movementId),
      };
      final confirmedMovement = await updated;
      if (!mounted) return;
      _acceptConfirmedMovement(confirmedMovement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Movement is now ${confirmedMovement.status.toLowerCase()}.',
          ),
        ),
      );
    } on StockMovementOutcomeUnknownException {
      if (!mounted) return;
      setState(() {
        _busyMovementId = null;
        _verificationPendingId = movement.movementId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The request is taking longer than expected. Verifying the '
            'movement status without repeating the action…',
          ),
        ),
      );
      await _verifyMovement(movement.movementId);
    } on StockMovementApiException catch (error) {
      if (!mounted) return;
      setState(() => _busyMovementId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  void _acceptConfirmedMovement(StockMovement movement) {
    if (!mounted) return;
    setState(() {
      final index = _movements.indexWhere(
        (item) => item.movementId == movement.movementId,
      );
      if (index >= 0) {
        _movements = [..._movements]..[index] = movement;
      } else {
        _movements = [movement, ..._movements];
      }
      _busyMovementId = null;
      _verificationPendingId = movement.status == 'IN_PROGRESS'
          ? movement.movementId
          : null;
    });
    widget.workflowController.updateMovement(movement);
  }

  Future<void> _verifyMovement(String movementId) async {
    if (_busyMovementId != null) return;
    setState(() => _busyMovementId = movementId);
    try {
      final movement = await _api.getMovement(movementId);
      if (!mounted) return;
      _acceptConfirmedMovement(movement);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            movement.status == 'IN_PROGRESS'
                ? 'Execution is still in progress. Use Check status before '
                      'taking another action.'
                : 'Verified movement status: ${_label(movement.status)}.',
          ),
        ),
      );
    } on StockMovementApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busyMovementId = null;
        _verificationPendingId = movementId;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${error.message} Use Check status to try again.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _generateAnotherRecommendation(StockMovement rejected) async {
    final candidateId = rejected.candidateId;
    if (_generatingReplacement || candidateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This recommendation is missing its candidate reference and '
            'cannot be regenerated safely.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Generate another recommendation?'),
        content: const Text(
          'The latest inventory and optimization data will be ranked again. '
          'The result may remain unchanged when the underlying conditions '
          'have not changed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _generatingReplacement = true);
    try {
      final replacement = await _api.recommendTransfer(candidateId);
      if (!mounted) return;

      // A manager may regenerate from the movement-history view after an app
      // restart, where no workflow is active in memory. In that case the new
      // backend-confirmed version still belongs in the history list. When the
      // matching workflow is active, also advance its focused review safely.
      widget.workflowController.replaceMovementVersion(replacement);

      setState(() {
        _movements = [
          replacement,
          ..._movements.where(
            (movement) => movement.movementId != replacement.movementId,
          ),
        ];
        _generatingReplacement = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New recommendation ${replacement.movementId} is ready for review.',
          ),
        ),
      );
    } on StockMovementOutcomeUnknownException {
      if (!mounted) return;
      setState(() => _generatingReplacement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recommendation generation is taking longer than expected. '
            'Open movement history and refresh before trying again.',
          ),
        ),
      );
    } on StockMovementApiException catch (error) {
      if (!mounted) return;
      setState(() => _generatingReplacement = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workflow = widget.workflowController.current;
    final showFocusedWorkflow =
        workflow?.movement != null && _showWorkflowMovement;
    final activeMovementId = widget.workflowController.movementId;
    final activeMovement = activeMovementId == null
        ? null
        : _movements.cast<StockMovement?>().firstWhere(
            (item) => item?.movementId == activeMovementId,
            orElse: () => workflow?.movement,
          );
    return ApplicationPageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFocusedWorkflow) ...[
            ApplicationPageHeader(
              title: 'Stock Movements',
              subtitle: 'Review, approve and track inventory transfers',
              onRefresh: _load,
              refreshTooltip: 'Refresh stock movements',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _openHistory,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to movement records'),
            ),
            const SizedBox(height: 14),
            ActiveWorkflowBanner(workflow: workflow!),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: WorkflowProgressIndicator(
                  currentStage: widget.workflowController.currentStage,
                  noReplenishmentRequired:
                      workflow.status == 'NO_ACTION_REQUIRED',
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (activeMovement == null)
              const _EmptyPanel(
                message:
                    'This active workflow does not contain a stock movement recommendation.',
              )
            else
              _FocusedMovementReview(
                movement: activeMovement,
                busy: _busyMovementId == activeMovement.movementId,
                verificationPending:
                    _verificationPendingId == activeMovement.movementId,
                onAction: (action) => _performAction(activeMovement, action),
                onCheckStatus: () => _verifyMovement(activeMovement.movementId),
                onOpenAnalytics: widget.onOpenAnalytics,
                onAskAssistant: widget.onAskAssistant,
                onOpenHistory: _openHistory,
                generatingReplacement: _generatingReplacement,
                onGenerateAnother: () =>
                    _generateAnotherRecommendation(activeMovement),
              ),
          ] else ...[
            if (workflow?.movement != null) ...[
              _AvailableWorkflowMovement(
                movement: workflow!.movement!,
                onOpen: () => setState(() => _showWorkflowMovement = true),
                onClear: widget.workflowController.clearActiveWorkflow,
              ),
              const SizedBox(height: 18),
            ],
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(64),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _ErrorPanel(message: _error!, onRetry: _load)
            else
              StockMovementWorkspace(
                movements: _movements,
                busyMovementId: _busyMovementId,
                generatingReplacement: _generatingReplacement,
                onRefresh: _load,
                onDetails: _showDetails,
                onAction: (movement, action) =>
                    _performAction(movement, switch (action) {
                      StockMovementWorkspaceAction.approve =>
                        _MovementAction.approve,
                      StockMovementWorkspaceAction.reject =>
                        _MovementAction.reject,
                      StockMovementWorkspaceAction.cancel =>
                        _MovementAction.cancel,
                      StockMovementWorkspaceAction.execute =>
                        _MovementAction.execute,
                    }),
                onGenerateAnother: _generateAnotherRecommendation,
                onCheckStatus: (movement) =>
                    _verifyMovement(movement.movementId),
              ),
          ],
        ],
      ),
    );
  }

  void _showDetails(StockMovement movement) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _MovementDetails(movement: movement),
          ),
        ),
      ),
    );
  }
}

/// Surfaces the workflow movement without replacing the normal records page.
class _AvailableWorkflowMovement extends StatelessWidget {
  const _AvailableWorkflowMovement({
    required this.movement,
    required this.onOpen,
    required this.onClear,
  });

  final StockMovement movement;
  final VoidCallback onOpen;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.swap_horiz_rounded),
          Text(
            'Workflow movement available: ${movement.productName}, '
            '${movement.fromStore} → ${movement.toStore}',
          ),
          TextButton(onPressed: onClear, child: const Text('Clear workflow')),
          FilledButton.tonal(
            onPressed: onOpen,
            child: const Text('Review workflow movement'),
          ),
        ],
      ),
    ),
  );
}

class _FocusedMovementReview extends StatelessWidget {
  const _FocusedMovementReview({
    required this.movement,
    required this.busy,
    required this.verificationPending,
    required this.onAction,
    required this.onCheckStatus,
    required this.onOpenAnalytics,
    required this.onAskAssistant,
    required this.onOpenHistory,
    required this.generatingReplacement,
    required this.onGenerateAnother,
  });

  final StockMovement movement;
  final bool busy;
  final bool verificationPending;
  final ValueChanged<_MovementAction> onAction;
  final VoidCallback onCheckStatus;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onAskAssistant;
  final VoidCallback onOpenHistory;
  final bool generatingReplacement;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
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
                      'Manager review',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Review the backend-confirmed recommendation before changing its status.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: movement.status),
            ],
          ),
          const SizedBox(height: 18),
          _MovementDetails(movement: movement, showCloseButton: false),
          if (movement.status == 'EXECUTED') ...[
            const SizedBox(height: 18),
            _MovementCompletionPanel(
              movement: movement,
              onOpenAnalytics: onOpenAnalytics,
              onAskAssistant: onAskAssistant,
              onOpenHistory: onOpenHistory,
            ),
          ],
          if (movement.status == 'REJECTED') ...[
            const SizedBox(height: 18),
            _RejectedRecommendationPanel(
              generating: generatingReplacement,
              onGenerateAnother: onGenerateAnother,
            ),
          ],
          const Divider(height: 32),
          if (verificationPending) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFAEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFEC84B)),
              ),
              child: const Text(
                'The last action has an unconfirmed or in-progress response. '
                'Check the backend status before taking another action.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (busy)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              children: [
                if (verificationPending)
                  OutlinedButton.icon(
                    onPressed: onCheckStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Check status'),
                  ),
                if (!verificationPending && movement.canReject)
                  OutlinedButton.icon(
                    onPressed: () => onAction(_MovementAction.reject),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                if (!verificationPending && movement.canCancel)
                  OutlinedButton.icon(
                    onPressed: () => onAction(_MovementAction.cancel),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('Cancel'),
                  ),
                if (!verificationPending && movement.canApprove)
                  FilledButton.icon(
                    onPressed: () => onAction(_MovementAction.approve),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                if (!verificationPending && movement.canExecute)
                  FilledButton.icon(
                    onPressed: () => onAction(_MovementAction.execute),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Execute transfer'),
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _MovementCompletionPanel extends StatelessWidget {
  const _MovementCompletionPanel({
    required this.movement,
    required this.onOpenAnalytics,
    required this.onAskAssistant,
    required this.onOpenHistory,
  });

  final StockMovement movement;
  final VoidCallback onOpenAnalytics;
  final VoidCallback onAskAssistant;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFECFDF3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF6CE9A6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF039855)),
            const SizedBox(width: 10),
            Text(
              'Transfer completed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 22,
          runSpacing: 12,
          children: [
            _Metric(label: 'Status', value: _label(movement.status)),
            _Metric(
              label: 'Executed quantity',
              value: '${movement.recommendedQuantity} units',
            ),
            _Metric(
              label: 'Source stock',
              value:
                  '${movement.sourceStockBefore} → ${movement.sourceStockAfter}',
            ),
            _Metric(
              label: 'Destination stock',
              value:
                  '${movement.targetStockBefore} → ${movement.targetStockAfter}',
            ),
            if (movement.transactionId != null)
              _Metric(label: 'Transaction', value: movement.transactionId!),
            if (movement.executedAt != null)
              _Metric(
                label: 'Completed',
                value: _dateTime(movement.executedAt),
              ),
          ],
        ),
        if (movement.executionSummary?.isNotEmpty == true) ...[
          const SizedBox(height: 14),
          Text(movement.executionSummary!),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onOpenAnalytics,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('View updated analytics'),
            ),
            OutlinedButton.icon(
              onPressed: onAskAssistant,
              icon: const Icon(Icons.forum_outlined),
              label: const Text('Ask Manager Assistant'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenHistory,
              icon: const Icon(Icons.history),
              label: const Text('View movement history'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.movements});
  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final values = <(String, int, IconData, Color)>[
      ('Total', movements.length, Icons.swap_horiz, AppTheme.primary),
      (
        'Recommended',
        movements.where((item) => item.status == 'RECOMMENDED').length,
        Icons.lightbulb_outline,
        Colors.orange,
      ),
      (
        'Approved',
        movements.where((item) => item.status == 'APPROVED').length,
        Icons.verified_outlined,
        Colors.blue,
      ),
      (
        'Executed',
        movements.where((item) => item.status == 'EXECUTED').length,
        Icons.check_circle_outline,
        Colors.green,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 620 ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final value in values)
              SizedBox(
                width: width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(value.$3, color: value.$4),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(value.$1, overflow: TextOverflow.ellipsis),
                              Text(
                                '${value.$2}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
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

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'ALL',
      'RECOMMENDED',
      'APPROVED',
      'EXECUTED',
      'REJECTED',
      'CANCELLED',
      'FAILED',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in statuses)
          ChoiceChip(
            label: Text(_label(status)),
            selected: value == status,
            onSelected: (_) => onChanged(status),
          ),
      ],
    );
  }
}

class _MovementCard extends StatelessWidget {
  const _MovementCard({
    required this.movement,
    required this.busy,
    required this.onAction,
    required this.onGenerateAnother,
    required this.onDetails,
  });
  final StockMovement movement;
  final bool busy;
  final ValueChanged<_MovementAction> onAction;
  final VoidCallback onGenerateAnother;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
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
                        movement.productName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${movement.productId} • ${movement.movementId}',
                        style: const TextStyle(color: Color(0xFF68758C)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: movement.status),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _Metric(
                  label: 'Route',
                  value: '${movement.fromStore} → ${movement.toStore}',
                ),
                _Metric(
                  label: 'Quantity',
                  value: '${movement.recommendedQuantity} units',
                ),
                _Metric(
                  label: 'Coverage',
                  value: '${movement.coveragePercentage.toStringAsFixed(0)}%',
                ),
                _Metric(label: 'Priority', value: _label(movement.priority)),
              ],
            ),
            const Divider(height: 30),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: busy ? null : onDetails,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                if (movement.status == 'REJECTED')
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onGenerateAnother,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Generate another'),
                  ),
                if (busy)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (movement.canApprove ||
                    movement.canReject ||
                    movement.canCancel ||
                    movement.canExecute)
                  PopupMenuButton<_MovementAction>(
                    tooltip: 'Movement actions',
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      if (movement.canApprove)
                        const PopupMenuItem(
                          value: _MovementAction.approve,
                          child: Text('Approve'),
                        ),
                      if (movement.canReject)
                        const PopupMenuItem(
                          value: _MovementAction.reject,
                          child: Text('Reject'),
                        ),
                      if (movement.canCancel)
                        const PopupMenuItem(
                          value: _MovementAction.cancel,
                          child: Text('Cancel'),
                        ),
                      if (movement.canExecute)
                        const PopupMenuItem(
                          value: _MovementAction.execute,
                          child: Text('Execute transfer'),
                        ),
                    ],
                    child: const Chip(
                      avatar: Icon(Icons.more_horiz, size: 18),
                      label: Text('Actions'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Guides the manager after a recommendation has been rejected.
///
/// Regeneration never edits the rejected movement. The backend creates and
/// returns a separately versioned recommendation using its current ranking
/// inputs.
class _RejectedRecommendationPanel extends StatelessWidget {
  const _RejectedRecommendationPanel({
    required this.generating,
    required this.onGenerateAnother,
  });

  final bool generating;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Recommendation rejected',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Generate another version using the latest available '
                  'inventory and optimization data. The result may be the '
                  'same if conditions have not changed.',
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: generating ? null : onGenerateAnother,
            icon: generating
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(
              generating ? 'Generating…' : 'Generate another recommendation',
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementDetails extends StatelessWidget {
  const _MovementDetails({required this.movement, this.showCloseButton = true});
  final StockMovement movement;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Movement details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            if (showCloseButton)
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        Text(movement.movementId, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 20),
        _DetailSection(
          title: 'Transfer plan',
          children: [
            _Metric(label: 'Product', value: movement.productName),
            _Metric(label: 'From', value: movement.fromStore),
            _Metric(label: 'To', value: movement.toStore),
            _Metric(
              label: 'Quantity',
              value: '${movement.recommendedQuantity} units',
            ),
          ],
        ),
        _DetailSection(
          title: 'Simulated inventory impact',
          children: [
            _Metric(
              label: 'Source stock',
              value:
                  '${movement.sourceStockBefore} → ${movement.sourceStockAfter}',
            ),
            _Metric(
              label: 'Target stock',
              value:
                  '${movement.targetStockBefore} → ${movement.targetStockAfter}',
            ),
            _Metric(
              label: 'Simulation',
              value: _label(movement.simulationStatus),
            ),
            _Metric(
              label: 'Confidence',
              value: '${movement.confidence.toStringAsFixed(0)}%',
            ),
          ],
        ),
        _DetailSection(
          title: 'Logistics estimate',
          children: [
            _Metric(
              label: 'Distance',
              value: '${movement.distanceKm.toStringAsFixed(1)} km',
            ),
            _Metric(
              label: 'Travel time',
              value: '${movement.estimatedTimeMinutes} min',
            ),
            _Metric(
              label: 'Estimated cost',
              value: 'LKR ${movement.estimatedTransferCost.toStringAsFixed(2)}',
            ),
          ],
        ),
        if (movement.recommendationReason != null)
          _TextSection(
            title: 'Recommendation reason',
            text: movement.recommendationReason!,
          ),
        if (movement.aiExplanation != null)
          _TextSection(title: 'AI explanation', text: movement.aiExplanation!),
        if (movement.transactionId != null)
          _TextSection(title: 'Transaction', text: movement.transactionId!),
        if (movement.rejectionReason != null)
          _TextSection(
            title: 'Rejection reason',
            text: movement.rejectionReason!,
          ),
        if (movement.cancelReason != null)
          _TextSection(
            title: 'Cancellation reason',
            text: movement.cancelReason!,
          ),
        if (movement.statusHistory.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'Status history',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final event in movement.statusHistory)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 10),
              title: Text(_label(event.status)),
              subtitle: Text(_dateTime(event.time)),
            ),
        ],
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Wrap(spacing: 24, runSpacing: 14, children: children),
      ],
    ),
  );
}

class _TextSection extends StatelessWidget {
  const _TextSection({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(text, style: const TextStyle(height: 1.45)),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF68758C))),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      'EXECUTED' => ApplicationStatusTone.success,
      'APPROVED' => ApplicationStatusTone.info,
      'REJECTED' || 'FAILED' => ApplicationStatusTone.danger,
      'CANCELLED' => ApplicationStatusTone.neutral,
      _ => ApplicationStatusTone.warning,
    };
    return ApplicationStatusBadge(label: _label(status), tone: tone);
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({this.message = 'No stock movements match this filter.'});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.swap_horiz, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    ),
  );
}

enum _MovementAction { approve, reject, cancel, execute }

extension on _MovementAction {
  String get label => switch (this) {
    _MovementAction.approve => 'Approve',
    _MovementAction.reject => 'Reject',
    _MovementAction.cancel => 'Cancel',
    _MovementAction.execute => 'Execute',
  };
}

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (part) =>
          part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}',
    )
    .join(' ');

String _dateTime(DateTime? value) {
  if (value == null) return 'Time unavailable';
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}';
}

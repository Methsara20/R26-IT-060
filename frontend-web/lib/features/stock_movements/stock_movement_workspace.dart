// Final-polish pass: standardizes stock-movement KPI cards and filter surfaces.
import 'package:flutter/material.dart';

import '../../models/stock_movement/stock_movement.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';

/// Actions exposed by the operational workspace. Network mutations remain in
/// [StockMovementsScreen], so this widget is presentation-only.
enum StockMovementWorkspaceAction { approve, reject, cancel, execute }

class StockMovementWorkspace extends StatefulWidget {
  const StockMovementWorkspace({
    required this.movements,
    required this.busyMovementId,
    required this.generatingReplacement,
    required this.onRefresh,
    required this.onDetails,
    required this.onAction,
    required this.onGenerateAnother,
    required this.onCheckStatus,
    super.key,
  });

  final List<StockMovement> movements;
  final String? busyMovementId;
  final bool generatingReplacement;
  final VoidCallback onRefresh;
  final ValueChanged<StockMovement> onDetails;
  final void Function(
    StockMovement movement,
    StockMovementWorkspaceAction action,
  )
  onAction;
  final ValueChanged<StockMovement> onGenerateAnother;
  final ValueChanged<StockMovement> onCheckStatus;

  @override
  State<StockMovementWorkspace> createState() => _StockMovementWorkspaceState();
}

class _StockMovementWorkspaceState extends State<StockMovementWorkspace> {
  static const _activeStatuses = {'RECOMMENDED', 'APPROVED', 'IN_PROGRESS'};
  static const _terminalStatuses = {
    'EXECUTED',
    'REJECTED',
    'CANCELLED',
    'FAILED',
  };

  final _searchController = TextEditingController();
  bool _showHistory = false;
  String _status = 'ALL';
  String _priority = 'ALL';
  String _fromStore = 'ALL';
  String _toStore = 'ALL';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movements = widget.movements;
    final active = movements
        .where((movement) => _activeStatuses.contains(movement.status))
        .toList();
    final history = movements
        .where((movement) => _terminalStatuses.contains(movement.status))
        .toList();
    final visible = _filter(_showHistory ? history : active);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WorkspaceHeader(onRefresh: widget.onRefresh),
        const SizedBox(height: 22),
        _LifecycleStrip(movements: movements),
        const SizedBox(height: 18),
        _KpiGrid(movements: movements),
        const SizedBox(height: 22),
        _WorkspaceTabs(
          showHistory: _showHistory,
          activeCount: active.length,
          historyCount: history.length,
          onChanged: (value) => setState(() => _showHistory = value),
        ),
        const SizedBox(height: 14),
        _FilterBar(
          controller: _searchController,
          movements: _showHistory ? history : active,
          status: _status,
          priority: _priority,
          fromStore: _fromStore,
          toStore: _toStore,
          onSearchChanged: (_) => setState(() {}),
          onStatusChanged: (value) => setState(() => _status = value),
          onPriorityChanged: (value) => setState(() => _priority = value),
          onFromChanged: (value) => setState(() => _fromStore = value),
          onToChanged: (value) => setState(() => _toStore = value),
          onClear: _clearFilters,
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          _EmptyQueue(showHistory: _showHistory, hasFilters: _hasFilters)
        else if (_showHistory)
          _HistoryList(
            movements: visible,
            generatingReplacement: widget.generatingReplacement,
            onDetails: widget.onDetails,
            onGenerateAnother: widget.onGenerateAnother,
          )
        else
          Column(
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                _ActiveMovementCard(
                  movement: visible[index],
                  busy: widget.busyMovementId == visible[index].movementId,
                  generatingReplacement: widget.generatingReplacement,
                  onDetails: () => widget.onDetails(visible[index]),
                  onAction: (action) => widget.onAction(visible[index], action),
                  onGenerateAnother: () =>
                      widget.onGenerateAnother(visible[index]),
                  onCheckStatus: () => widget.onCheckStatus(visible[index]),
                ),
                if (index != visible.length - 1) const SizedBox(height: 14),
              ],
            ],
          ),
      ],
    );
  }

  bool get _hasFilters =>
      _searchController.text.trim().isNotEmpty ||
      _status != 'ALL' ||
      _priority != 'ALL' ||
      _fromStore != 'ALL' ||
      _toStore != 'ALL';

  List<StockMovement> _filter(List<StockMovement> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((movement) {
      final matchesQuery =
          query.isEmpty ||
          movement.productName.toLowerCase().contains(query) ||
          movement.productId.toLowerCase().contains(query) ||
          movement.movementId.toLowerCase().contains(query);
      return matchesQuery &&
          (_status == 'ALL' || movement.status == _status) &&
          (_priority == 'ALL' || movement.priority == _priority) &&
          (_fromStore == 'ALL' || movement.fromStore == _fromStore) &&
          (_toStore == 'ALL' || movement.toStore == _toStore);
    }).toList();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _status = 'ALL';
      _priority = 'ALL';
      _fromStore = 'ALL';
      _toStore = 'ALL';
    });
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => ApplicationPageHeader(
    title: 'Stock Movements',
    subtitle: 'Review, approve and track inventory transfers',
    onRefresh: onRefresh,
    refreshTooltip: 'Refresh movements',
  );
}

class _LifecycleStrip extends StatelessWidget {
  const _LifecycleStrip({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final stages = [
      ('Recommended', 'RECOMMENDED', Icons.lightbulb_outline),
      ('Approved', 'APPROVED', Icons.verified_outlined),
      ('Execution', 'IN_PROGRESS', Icons.local_shipping_outlined),
      ('Completed', 'EXECUTED', Icons.task_alt),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: _panelDecoration(context),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var index = 0; index < stages.length; index++) ...[
              _LifecycleStage(
                icon: stages[index].$3,
                label: stages[index].$1,
                count: movements
                    .where((movement) => movement.status == stages[index].$2)
                    .length,
              ),
              if (index != stages.length - 1 && constraints.maxWidth > 620)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Color(0xFF98A2B3),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LifecycleStage extends StatelessWidget {
  const _LifecycleStage({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF4763A4)),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text('$count', style: const TextStyle(color: Color(0xFF5D6B82))),
      ],
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.movements});

  final List<StockMovement> movements;

  @override
  Widget build(BuildContext context) {
    final cards = [
      (
        'Needs review',
        movements.where((item) => item.status == 'RECOMMENDED').length,
        Icons.fact_check_outlined,
        const Color(0xFF2563EB),
      ),
      (
        'Ready to execute',
        movements.where((item) => item.status == 'APPROVED').length,
        Icons.play_circle_outline,
        const Color(0xFFF59E0B),
      ),
      (
        'Completed',
        movements.where((item) => item.status == 'EXECUTED').length,
        Icons.check_circle_outline,
        const Color(0xFF16A36A),
      ),
      (
        'Issues',
        movements.where((item) => item.status == 'FAILED').length,
        Icons.error_outline,
        const Color(0xFFDC2F2F),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: _KpiCard(
                  label: card.$1,
                  value: card.$2,
                  icon: card.$3,
                  color: card.$4,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => ApplicationStatCard(
    label: label,
    value: '$value',
    icon: icon,
    accentColor: color,
    showAccentBar: false,
  );
}

class _WorkspaceTabs extends StatelessWidget {
  const _WorkspaceTabs({
    required this.showHistory,
    required this.activeCount,
    required this.historyCount,
    required this.onChanged,
  });

  final bool showHistory;
  final int activeCount;
  final int historyCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _TabButton(
        selected: !showHistory,
        label: 'Active queue',
        count: activeCount,
        onTap: () => onChanged(false),
      ),
      const SizedBox(width: 8),
      _TabButton(
        selected: showHistory,
        label: 'History',
        count: historyCount,
        onTap: () => onChanged(true),
      ),
    ],
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.tonal(onPressed: onTap, child: Text('$label  $count'))
      : TextButton(onPressed: onTap, child: Text('$label  $count'));
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.movements,
    required this.status,
    required this.priority,
    required this.fromStore,
    required this.toStore,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final List<StockMovement> movements;
  final String status;
  final String priority;
  final String fromStore;
  final String toStore;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<String> onFromChanged;
  final ValueChanged<String> onToChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final statuses = _values(movements.map((item) => item.status));
    final priorities = _values(movements.map((item) => item.priority));
    final fromStores = _values(movements.map((item) => item.fromStore));
    final toStores = _values(movements.map((item) => item.toStore));
    return ApplicationFilterBar(
      children: [
        SizedBox(
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 760;
              final search = TextField(
                controller: controller,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search movements',
                  hintText: 'Product name, product ID or movement ID',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              );
              final filters = Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FilterDropdown(
                    label: 'Status',
                    value: status,
                    values: statuses,
                    onChanged: onStatusChanged,
                  ),
                  _FilterDropdown(
                    label: 'Priority',
                    value: priority,
                    values: priorities,
                    onChanged: onPriorityChanged,
                  ),
                  _FilterDropdown(
                    label: 'From',
                    value: fromStore,
                    values: fromStores,
                    onChanged: onFromChanged,
                  ),
                  _FilterDropdown(
                    label: 'To',
                    value: toStore,
                    values: toStores,
                    onChanged: onToChanged,
                  ),
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Clear'),
                  ),
                ],
              );
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 12), filters],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  Flexible(flex: 2, child: filters),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static List<String> _values(Iterable<String> values) {
    final result = values.where((value) => value.isNotEmpty).toSet().toList()
      ..sort();
    return ['ALL', ...result];
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => ApplicationFilterDropdown(
    label: label,
    value: value,
    items: {for (final item in values) item: _label(item)},
    onChanged: onChanged,
    width: 132,
  );
}

class _ActiveMovementCard extends StatelessWidget {
  const _ActiveMovementCard({
    required this.movement,
    required this.busy,
    required this.generatingReplacement,
    required this.onDetails,
    required this.onAction,
    required this.onGenerateAnother,
    required this.onCheckStatus,
  });

  final StockMovement movement;
  final bool busy;
  final bool generatingReplacement;
  final VoidCallback onDetails;
  final ValueChanged<StockMovementWorkspaceAction> onAction;
  final VoidCallback onGenerateAnother;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: _panelDecoration(context),
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
                    '${movement.productId}  •  ${movement.movementId}',
                    style: const TextStyle(color: Color(0xFF68758D)),
                  ),
                ],
              ),
            ),
            _StatusPill(status: movement.status),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final route = _RouteVisual(movement: movement);
            final impact = _InventoryImpact(movement: movement);
            return compact
                ? Column(children: [route, const SizedBox(height: 14), impact])
                : Row(
                    // This workspace is inside a vertical scroll view, so its
                    // height is intentionally unbounded. Stretching the row's
                    // children would force an infinite height during layout.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: route),
                      const SizedBox(width: 14),
                      Expanded(flex: 2, child: impact),
                    ],
                  );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _MetadataChip(
              icon: Icons.flag_outlined,
              label: _label(movement.priority),
            ),
            const SizedBox(width: 8),
            _MetadataChip(
              icon: Icons.speed,
              label: '${movement.confidence.toStringAsFixed(0)}% confidence',
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(Icons.visibility_outlined, size: 18),
              label: const Text('View details'),
            ),
          ],
        ),
        const Divider(height: 24),
        _ActionRow(
          movement: movement,
          busy: busy,
          generatingReplacement: generatingReplacement,
          onAction: onAction,
          onGenerateAnother: onGenerateAnother,
          onCheckStatus: onCheckStatus,
        ),
      ],
    ),
  );
}

class _RouteVisual extends StatelessWidget {
  const _RouteVisual({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRANSFER ROUTE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .7,
            color: Color(0xFF68758D),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            _StoreNode(label: movement.fromStore, caption: 'Source'),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Icon(Icons.arrow_forward, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            _StoreNode(label: movement.toStore, caption: 'Destination'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '${movement.recommendedQuantity} units recommended for transfer',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _StoreNode extends StatelessWidget {
  const _StoreNode({required this.label, required this.caption});

  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        caption,
        style: const TextStyle(fontSize: 12, color: Color(0xFF68758D)),
      ),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

class _InventoryImpact extends StatelessWidget {
  const _InventoryImpact({required this.movement});

  final StockMovement movement;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      border: Border.all(color: const Color(0xFFE3E8F1)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Inventory impact',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _ImpactLine(
          label: 'Source stock',
          before: movement.sourceStockBefore,
          after: movement.sourceStockAfter,
        ),
        const SizedBox(height: 8),
        _ImpactLine(
          label: 'Destination stock',
          before: movement.targetStockBefore,
          after: movement.targetStockAfter,
        ),
        const SizedBox(height: 9),
        Text(
          '${movement.coveragePercentage.toStringAsFixed(0)}% demand coverage',
          style: const TextStyle(
            color: Color(0xFF4763A4),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _ImpactLine extends StatelessWidget {
  const _ImpactLine({
    required this.label,
    required this.before,
    required this.after,
  });

  final String label;
  final int before;
  final int after;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(color: Color(0xFF68758D))),
      ),
      Text(
        '$before → $after',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF68758D)),
          const SizedBox(width: 5),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.movement,
    required this.busy,
    required this.generatingReplacement,
    required this.onAction,
    required this.onGenerateAnother,
    required this.onCheckStatus,
  });

  final StockMovement movement;
  final bool busy;
  final bool generatingReplacement;
  final ValueChanged<StockMovementWorkspaceAction> onAction;
  final VoidCallback onGenerateAnother;
  final VoidCallback onCheckStatus;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Updating movement…'),
        ],
      );
    }
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      alignment: WrapAlignment.end,
      children: [
        if (movement.canReject)
          OutlinedButton(
            onPressed: () => onAction(StockMovementWorkspaceAction.reject),
            child: const Text('Reject'),
          ),
        if (movement.canCancel)
          TextButton(
            onPressed: () => onAction(StockMovementWorkspaceAction.cancel),
            child: const Text('Cancel'),
          ),
        if (movement.canApprove)
          FilledButton.icon(
            onPressed: () => onAction(StockMovementWorkspaceAction.approve),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve transfer'),
          ),
        if (movement.canExecute)
          FilledButton.icon(
            onPressed: () => onAction(StockMovementWorkspaceAction.execute),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Execute transfer'),
          ),
        if (movement.status == 'IN_PROGRESS')
          FilledButton.tonalIcon(
            onPressed: onCheckStatus,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Check status'),
          ),
        if (movement.status == 'REJECTED' && movement.candidateId != null)
          FilledButton.tonalIcon(
            onPressed: generatingReplacement ? null : onGenerateAnother,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Generate another'),
          ),
      ],
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.movements,
    required this.generatingReplacement,
    required this.onDetails,
    required this.onGenerateAnother,
  });

  final List<StockMovement> movements;
  final bool generatingReplacement;
  final ValueChanged<StockMovement> onDetails;
  final ValueChanged<StockMovement> onGenerateAnother;

  @override
  Widget build(BuildContext context) => Container(
    decoration: _panelDecoration(context),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < movements.length; index++) ...[
          _HistoryRow(
            movement: movements[index],
            generatingReplacement: generatingReplacement,
            onDetails: () => onDetails(movements[index]),
            onGenerateAnother: () => onGenerateAnother(movements[index]),
          ),
          if (index != movements.length - 1) const Divider(height: 1),
        ],
      ],
    ),
  );
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.movement,
    required this.generatingReplacement,
    required this.onDetails,
    required this.onGenerateAnother,
  });

  final StockMovement movement;
  final bool generatingReplacement;
  final VoidCallback onDetails;
  final VoidCallback onGenerateAnother;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onDetails,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final identity = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement.productName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${movement.productId} • ${movement.movementId}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68758D),
                  ),
                ),
              ],
            );
            final facts = Wrap(
              spacing: 18,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('${movement.fromStore} → ${movement.toStore}'),
                Text('${movement.recommendedQuantity} units'),
                _StatusPill(status: movement.status),
                if (movement.status == 'REJECTED' &&
                    movement.candidateId != null)
                  TextButton.icon(
                    onPressed: generatingReplacement ? null : onGenerateAnother,
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Generate another'),
                  ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Color(0xFF98A2B3),
                ),
              ],
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 10), facts],
              );
            }
            return Row(
              children: [
                Expanded(flex: 2, child: identity),
                const SizedBox(width: 14),
                Expanded(flex: 3, child: facts),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'RECOMMENDED' => const Color(0xFFF59E0B),
      'APPROVED' || 'IN_PROGRESS' => const Color(0xFF2563EB),
      'EXECUTED' => const Color(0xFF16A36A),
      'FAILED' || 'REJECTED' => const Color(0xFFDC2F2F),
      _ => const Color(0xFF68758D),
    };
    return ApplicationStatusBadge(label: _label(status), color: color);
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({required this.showHistory, required this.hasFilters});

  final bool showHistory;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
    decoration: _panelDecoration(context),
    child: Column(
      children: [
        const Icon(
          Icons.swap_horiz_rounded,
          size: 34,
          color: Color(0xFF4763A4),
        ),
        const SizedBox(height: 12),
        Text(
          hasFilters
              ? 'No movements match these filters'
              : showHistory
              ? 'No movement history yet'
              : 'No active transfers require attention',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          hasFilters
              ? 'Clear or adjust the filters to see more results.'
              : showHistory
              ? 'Completed and closed movements will appear here.'
              : 'New backend recommendations will appear in this queue.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF68758D)),
        ),
      ],
    ),
  );
}

BoxDecoration _panelDecoration(BuildContext context) => BoxDecoration(
  color: Theme.of(context).colorScheme.surface,
  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
  borderRadius: BorderRadius.circular(14),
);

String _label(String value) => value
    .toLowerCase()
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

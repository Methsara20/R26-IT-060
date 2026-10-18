import 'package:flutter/material.dart';
import '../../core/auth/inventory_api_client.dart';
import '../../core/auth/inventory_auth_scope.dart';
import '../../core/auth/inventory_session_controller.dart';
import '../../core/auth/inventory_ui_permissions.dart';
import '../../core/widgets/application_feedback_components.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../models/marketing_review/inventory_campaign_review.dart';
import '../../services/inventory_marketing_review_api_service.dart';

class MarketingRequestsScreen extends StatefulWidget {
  const MarketingRequestsScreen({this.client, super.key});
  final InventoryApiClient? client;
  @override
  State<MarketingRequestsScreen> createState() =>
      _MarketingRequestsScreenState();
}

class _MarketingRequestsScreenState extends State<MarketingRequestsScreen> {
  late final InventorySessionController session;
  late final InventoryApiClient client;
  late final InventoryMarketingReviewApiService api;
  InventoryCampaignReviewPage? page;
  InventorySessionLease? pageLease;
  String filter = 'ALL';
  String? error;
  bool loading = false;
  String? busyId;
  int generation = 0;
  final searchController = TextEditingController();
  String query = '';

  bool get canView =>
      session.user != null &&
      InventoryUiPermissions(
        session.user!,
      ).can(InventoryOperation.readMarketingRequests);
  bool get canDecide =>
      session.user != null &&
      InventoryUiPermissions(
        session.user!,
      ).can(InventoryOperation.decideMarketingRequests);

  @override
  void initState() {
    super.initState();
    session = InventoryAuthScope.read(context);
    client = widget.client ?? InventoryApiClient(session: session);
    api = InventoryMarketingReviewApiService(client: client, session: session);
    if (canView) load();
  }

  @override
  void dispose() {
    generation++;
    searchController.dispose();
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> load() async {
    if (!canView) return;
    final request = ++generation;
    final lease = session.capture();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.list();
      if (mounted && request == generation && session.isCurrent(lease)) {
        setState(() {
          page = result;
          pageLease = lease;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = inventoryMarketingReviewMessage(e));
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> open(InventoryCampaignReview summary) async {
    final lease = session.capture();
    setState(() => busyId = summary.requestId);
    try {
      final item = await api.detail(summary.requestId);
      if (!mounted || !session.isCurrent(lease)) return;
      setState(() => busyId = null);
      await showDialog<void>(
        context: context,
        builder: (_) => _RequestDetails(
          item: item,
          canDecide: canDecide,
          onAccept: () => decide(item, true),
          onReject: () => decide(item, false),
        ),
      );
    } catch (e) {
      if (mounted) _message(inventoryMarketingReviewMessage(e));
    } finally {
      if (mounted && busyId == summary.requestId) {
        setState(() => busyId = null);
      }
    }
  }

  Future<void> decide(InventoryCampaignReview item, bool accept) async {
    if (!canDecide || !item.pending || busyId != null) return;
    final lease = session.capture();
    String? reason;
    if (accept) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Generate baseline forecast?'),
          content: Text(
            'Run a baseline stock and demand assessment for ${item.campaignName}? Promotional uplift will not be predicted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generate Forecast'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      reason = await showDialog<String>(
        context: context,
        builder: (_) => const _RejectDialog(),
      );
      if (reason == null) return;
    }
    if (!mounted || !session.isCurrent(lease) || !canDecide) return;
    Navigator.of(context).pop();
    setState(() => busyId = item.requestId);
    try {
      if (accept) {
        await api.accept(item.requestId);
      } else {
        await api.reject(item.requestId, reason!);
      }
      if (mounted && session.isCurrent(lease)) {
        _message(
          accept
              ? 'Campaign assessment completed.'
              : 'Campaign request rejected.',
        );
        await load();
      }
    } catch (e) {
      if (mounted) {
        _message(inventoryMarketingReviewMessage(e));
        if (e is InventoryMarketingReviewException && e.status == 409) {
          await load();
        }
      }
    } finally {
      if (mounted) {
        setState(() => busyId = null);
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    InventoryAuthScope.of(context);
    if (!canView) {
      return const Center(
        child: Text('Inventory access denied for Marketing Requests.'),
      );
    }
    final current = pageLease != null && session.isCurrent(pageLease!)
        ? page
        : null;
    final loadedItems = current?.items ?? const <InventoryCampaignReview>[];
    final normalizedQuery = query.trim().toLowerCase();
    final items = loadedItems.where((item) {
      final statusMatches = filter == 'ALL' || item.status == filter;
      final searchMatches =
          normalizedQuery.isEmpty ||
          [
            item.campaignName,
            item.campaignReference,
            item.requestId,
            item.productId,
            item.storeId,
          ].any((value) => value.toLowerCase().contains(normalizedQuery));
      return statusMatches && searchMatches;
    }).toList();
    final hasFilters = filter != 'ALL' || normalizedQuery.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApplicationPageHeader(
          contextLabel: 'MARKETING CAMPAIGN REVIEW',
          leadingIcon: Icons.campaign_outlined,
          title: 'Marketing Requests',
          subtitle:
              'Review campaign proposals using baseline stock and demand assessments.',
          onRefresh: load,
          refreshing: loading,
          refreshTooltip: 'Refresh requests',
          premium: true,
        ),
        const SizedBox(height: 24),
        if (current == null && loading)
          const _RequestsLoadingState()
        else if (current == null && error != null)
          ApplicationErrorState(
            title: 'Marketing requests unavailable',
            message: error!,
            onRetry: load,
          )
        else ...[
          _RequestOverview(items: loadedItems),
          const SizedBox(height: 20),
          ApplicationSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ApplicationSectionHeader(
                  title: 'Campaign request directory',
                  subtitle:
                      'Search and status filters apply only to the currently loaded page.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: 'Search loaded requests',
                    hintText:
                        'Campaign, reference, request, product or showroom ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              searchController.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final value in _statusFilters)
                      FilterChip(
                        label: Text(
                          value == 'ALL'
                              ? 'All on this page'
                              : _statusLabel(value),
                        ),
                        selected: filter == value,
                        onSelected: (_) => setState(() => filter = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${items.length} of ${loadedItems.length} loaded requests shown',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (hasFilters)
                      TextButton.icon(
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            query = '';
                            filter = 'ALL';
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Clear filters'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(
              semanticsLabel: 'Refreshing Marketing requests',
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            ApplicationInlineNotice(
              title: 'The latest refresh failed',
              message: '$error Previously loaded requests remain visible.',
              tone: ApplicationNoticeTone.danger,
              action: TextButton(onPressed: load, child: const Text('Retry')),
            ),
          ],
          const SizedBox(height: 20),
          if (items.isEmpty)
            ApplicationEmptyState(
              icon: hasFilters
                  ? Icons.search_off_outlined
                  : Icons.mark_email_read_outlined,
              title: hasFilters
                  ? 'No requests match these filters'
                  : 'No Marketing requests on this page',
              message: hasFilters
                  ? 'Clear the current-page search or status filter to see other loaded requests.'
                  : 'New campaign requests assigned to your authorized showrooms will appear here.',
              action: hasFilters
                  ? OutlinedButton.icon(
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          query = '';
                          filter = 'ALL';
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('Clear filters'),
                    )
                  : null,
            )
          else
            for (final item in items) ...[
              _RequestCard(
                item: item,
                busy: busyId == item.requestId,
                onOpen: () => open(item),
              ),
              const SizedBox(height: 12),
            ],
          if (current != null)
            Text(
              current.items.isEmpty
                  ? 'This loaded page contains no requests.'
                  : 'Loaded ${current.skip + 1}–${current.skip + current.items.length} of ${current.total} requests.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.item,
    required this.busy,
    required this.onOpen,
  });
  final InventoryCampaignReview item;
  final bool busy;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => ApplicationInteractiveCard(
    onPressed: busy ? null : onOpen,
    semanticLabel:
        'Open ${item.campaignName}, ${_statusLabel(item.status)}, product ${item.productId}, showroom ${item.storeId}',
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final heading = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.pending
                    ? Icons.mark_email_unread_outlined
                    : Icons.campaign_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.campaignName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.campaignReference} · ${item.requestId}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: 12), _Status(item.status)],
            const SizedBox(width: 8),
            if (busy)
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (compact) ...[const SizedBox(height: 12), _Status(item.status)],
            const SizedBox(height: 16),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _CardFact(
                  icon: Icons.inventory_2_outlined,
                  label: 'Product',
                  value: item.productId,
                ),
                _CardFact(
                  icon: Icons.storefront_outlined,
                  label: 'Showroom',
                  value: item.storeId,
                ),
                _CardFact(
                  icon: Icons.date_range_outlined,
                  label: 'Campaign dates',
                  value: '${_date(item.startDate)} – ${_date(item.endDate)}',
                ),
                _CardFact(
                  icon: Icons.local_offer_outlined,
                  label: 'Promotion',
                  value: _promotion(item),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

class _RequestDetails extends StatelessWidget {
  const _RequestDetails({
    required this.item,
    required this.canDecide,
    required this.onAccept,
    required this.onReject,
  });
  final InventoryCampaignReview item;
  final bool canDecide;
  final VoidCallback onAccept, onReject;
  @override
  Widget build(BuildContext context) {
    final a = item.assessment;
    return AlertDialog(
      icon: const Icon(Icons.campaign_outlined),
      title: Text(item.campaignName),
      titlePadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Status(item.status),
                  ApplicationStatusBadge(
                    label: item.requestId,
                    icon: Icons.tag,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailSection(
                title: 'Campaign request',
                icon: Icons.description_outlined,
                children: [
                  _DetailField('Campaign reference', item.campaignReference),
                  _DetailField('Product ID', item.productId),
                  _DetailField('Showroom ID', item.storeId),
                  _DetailField(
                    'Campaign dates',
                    '${_date(item.startDate)} – ${_date(item.endDate)}',
                  ),
                  _DetailField('Promotion', _promotion(item)),
                ],
              ),
              if (a != null) ...[
                const SizedBox(height: 20),
                const ApplicationInlineNotice(
                  title: 'Baseline assessment',
                  message:
                      'This is a baseline forecast. It is not a promotion-adjusted prediction.',
                ),
                const SizedBox(height: 16),
                _AssessmentGrid(assessment: a),
                if (a.explanation != null && a.explanation!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Assessment explanation',
                    icon: Icons.insights_outlined,
                    children: [_DetailField('Explanation', a.explanation!)],
                  ),
                ],
              ],
              if (item.rejectionReason != null) ...[
                const SizedBox(height: 20),
                ApplicationInlineNotice(
                  title: 'Request rejected',
                  message: item.rejectionReason,
                  tone: ApplicationNoticeTone.danger,
                ),
              ],
              if (item.review != null) ...[
                const SizedBox(height: 20),
                _DetailSection(
                  title: 'Review record',
                  icon: Icons.verified_user_outlined,
                  children: [
                    _DetailField(
                      'Reviewed by',
                      '${item.review!.name}${item.review!.role == null ? '' : ' (${item.review!.role})'}',
                    ),
                    if (item.review!.decision != null)
                      _DetailField('Decision', item.review!.decision!),
                    if (item.review!.decidedAt != null)
                      _DetailField(
                        'Decision timestamp',
                        item.review!.decidedAt!,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (canDecide && item.pending) ...[
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
          ),
          FilledButton.icon(
            onPressed: onAccept,
            icon: const Icon(Icons.auto_graph_outlined),
            label: const Text('Generate Forecast'),
          ),
        ],
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();
  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: Icon(
      Icons.block_outlined,
      color: Theme.of(context).colorScheme.error,
    ),
    title: const Text('Reject campaign request?'),
    content: SizedBox(
      width: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Marketing will see this reason. Explain why the request cannot proceed.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 500,
            maxLines: 4,
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            decoration: InputDecoration(
              labelText: 'Rejection reason',
              hintText: 'Enter a clear reason for Marketing',
              helperText: 'Required · 3–500 characters',
              errorText: error,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: () {
          final value = controller.text.trim();
          if (value.length < 3) {
            setState(() => error = 'Enter a meaningful reason.');
            return;
          }
          Navigator.pop(context, value);
        },
        icon: const Icon(Icons.block_outlined),
        label: const Text('Confirm rejection'),
      ),
    ],
  );
}

class _Status extends StatelessWidget {
  const _Status(this.value);
  final String value;
  @override
  Widget build(BuildContext context) => ApplicationStatusBadge(
    label: _statusLabel(value),
    tone: _statusTone(value),
    icon: _statusIcon(value),
  );
}

class _RequestOverview extends StatelessWidget {
  const _RequestOverview({required this.items});
  final List<InventoryCampaignReview> items;

  @override
  Widget build(BuildContext context) {
    int count(String status) => items.where((i) => i.status == status).length;
    final attention = items
        .where(
          (i) => const {
            'REJECTED',
            'FAILED',
            'UNSUPPORTED_PERIOD',
          }.contains(i.status),
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ApplicationSectionHeader(
          title: 'Current-page overview',
          subtitle:
              'These counts describe only the requests returned on the currently loaded page.',
        ),
        const SizedBox(height: 14),
        ApplicationResponsiveGrid(
          minItemWidth: 170,
          maxColumns: 5,
          children: [
            _OverviewCard(
              label: 'Requests loaded',
              value: items.length,
              icon: Icons.inbox_outlined,
            ),
            _OverviewCard(
              label: 'Pending review',
              value: count('PENDING_REVIEW'),
              icon: Icons.pending_actions_outlined,
              tone: ApplicationStatusTone.warning,
            ),
            _OverviewCard(
              label: 'Processing',
              value: count('PROCESSING'),
              icon: Icons.autorenew,
              tone: ApplicationStatusTone.info,
            ),
            _OverviewCard(
              label: 'Completed',
              value: count('COMPLETED'),
              icon: Icons.check_circle_outline,
              tone: ApplicationStatusTone.success,
            ),
            _OverviewCard(
              label: 'Attention required',
              value: attention,
              icon: Icons.warning_amber_rounded,
              tone: ApplicationStatusTone.danger,
            ),
          ],
        ),
      ],
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.icon,
    this.tone = ApplicationStatusTone.neutral,
  });
  final String label;
  final int value;
  final IconData icon;
  final ApplicationStatusTone tone;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        Icon(icon, color: _toneColor(context, tone)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CardFact extends StatelessWidget {
  const _CardFact({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 150, maxWidth: 290),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$label: $value',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    muted: true,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 24, runSpacing: 12, children: children),
      ],
    ),
  );
}

class _DetailField extends StatelessWidget {
  const _DetailField(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 180, maxWidth: 430),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(value),
      ],
    ),
  );
}

class _AssessmentGrid extends StatelessWidget {
  const _AssessmentGrid({required this.assessment});
  final CampaignAssessment assessment;

  @override
  Widget build(BuildContext context) => ApplicationResponsiveGrid(
    minItemWidth: 190,
    maxColumns: 2,
    children: [
      _AssessmentCard(
        label: 'Available stock',
        value: assessment.availableStock?.toString() ?? 'Unavailable',
        icon: Icons.inventory_2_outlined,
      ),
      _AssessmentCard(
        label: 'Forecast demand',
        value: assessment.forecastDemand?.toString() ?? 'Unavailable',
        icon: Icons.auto_graph_outlined,
      ),
      _AssessmentCard(
        label: 'Forecast period',
        value:
            '${assessment.forecastStartDate ?? 'Unavailable'} – ${assessment.forecastEndDate ?? 'Unavailable'}',
        icon: Icons.date_range_outlined,
      ),
      _AssessmentCard(
        label: 'Stock sufficiency',
        value: assessment.stockSufficiency ?? 'Unknown',
        icon: Icons.fact_check_outlined,
      ),
    ],
  );
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RequestsLoadingState extends StatelessWidget {
  const _RequestsLoadingState();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ApplicationLoadingSkeleton(height: 104),
      SizedBox(height: 16),
      ApplicationLoadingSkeleton(height: 150),
      SizedBox(height: 12),
      ApplicationLoadingSkeleton(height: 150),
    ],
  );
}

const _statusFilters = [
  'ALL',
  'PENDING_REVIEW',
  'PROCESSING',
  'COMPLETED',
  'REJECTED',
  'FAILED',
  'UNSUPPORTED_PERIOD',
];

String _statusLabel(String value) => switch (value) {
  'PENDING_REVIEW' => 'Pending review',
  'PROCESSING' => 'Processing',
  'COMPLETED' => 'Completed',
  'REJECTED' => 'Rejected',
  'FAILED' => 'Failed',
  'UNSUPPORTED_PERIOD' => 'Unsupported period',
  _ => value.replaceAll('_', ' '),
};

ApplicationStatusTone _statusTone(String value) => switch (value) {
  'PENDING_REVIEW' || 'UNSUPPORTED_PERIOD' => ApplicationStatusTone.warning,
  'PROCESSING' => ApplicationStatusTone.info,
  'COMPLETED' => ApplicationStatusTone.success,
  'REJECTED' || 'FAILED' => ApplicationStatusTone.danger,
  _ => ApplicationStatusTone.neutral,
};

IconData _statusIcon(String value) => switch (value) {
  'PENDING_REVIEW' => Icons.pending_actions_outlined,
  'PROCESSING' => Icons.autorenew,
  'COMPLETED' => Icons.check_circle_outline,
  'REJECTED' => Icons.block_outlined,
  'FAILED' => Icons.error_outline,
  'UNSUPPORTED_PERIOD' => Icons.event_busy_outlined,
  _ => Icons.info_outline,
};

Color _toneColor(BuildContext context, ApplicationStatusTone tone) =>
    switch (tone) {
      ApplicationStatusTone.info => Theme.of(context).colorScheme.primary,
      ApplicationStatusTone.success => Colors.green,
      ApplicationStatusTone.warning => Colors.orange,
      ApplicationStatusTone.danger => Theme.of(context).colorScheme.error,
      ApplicationStatusTone.neutral => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };

String _promotion(InventoryCampaignReview item) {
  final type = item.promotionType;
  final discount = item.discountPercent;
  if (type == null || type.isEmpty) return 'No promotion specified';
  if (discount == null) return type;
  return '$type · ${discount.toStringAsFixed(discount % 1 == 0 ? 0 : 1)}%';
}

String _date(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

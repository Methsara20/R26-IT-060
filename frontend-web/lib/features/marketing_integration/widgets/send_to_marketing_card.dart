import 'package:flutter/material.dart';

import '../../../core/theme/application_design_tokens.dart';
import '../models/marketing_opportunity.dart';
import '../services/marketing_opportunity_api_service.dart';

class SendToMarketingCard extends StatefulWidget {
  const SendToMarketingCard({
    required this.opportunity,
    this.service,
    super.key,
  });

  final MarketingOpportunityRequest opportunity;
  final MarketingOpportunityApiService? service;

  @override
  State<SendToMarketingCard> createState() => _SendToMarketingCardState();
}

class _SendToMarketingCardState extends State<SendToMarketingCard> {
  late final MarketingOpportunityApiService _service;
  bool _sending = false;
  MarketingOpportunityResponse? _response;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MarketingOpportunityApiService();
  }

  @override
  void didUpdateWidget(covariant SendToMarketingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opportunity.workflowId != widget.opportunity.workflowId) {
      _sending = false;
      _response = null;
      _error = null;
    }
  }

  Future<void> _confirmAndSend() async {
    if (_sending || _response != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _MarketingConfirmationDialog(opportunity: widget.opportunity),
    );
    if (confirmed != true || !mounted) return;
    await _send();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final response = await _service.create(widget.opportunity);
      if (!mounted) return;
      setState(() => _response = response);
    } on MarketingOpportunityApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'Unable to send this opportunity to Marketing. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.opportunity.recommendedAction.trim().toUpperCase() !=
        'PROMOTE') {
      return const SizedBox.shrink();
    }
    final response = _response;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ApplicationSpacing.medium),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(ApplicationRadii.card),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                response == null
                    ? Icons.campaign_outlined
                    : Icons.check_circle_outline,
                color: response == null
                    ? Theme.of(context).colorScheme.primary
                    : ApplicationColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      response == null
                          ? 'Marketing Opportunity'
                          : 'Sent to Marketing',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      response == null
                          ? 'This inventory condition may benefit from '
                                'personalized promotional activity.'
                          : 'The inventory opportunity is now available to the '
                                'Personalized Marketing component.',
                    ),
                    if (response != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Reference: ${response.opportunityId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (response == null &&
                        widget.opportunity.promotionPercent != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Forecast Promotion Scenario: '
                        '${_percentage(widget.opportunity.promotionPercent!)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (response == null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _sending ? null : _confirmAndSend,
              icon: _sending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: Text(_sending ? 'Sending…' : 'Send to Marketing'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketingConfirmationDialog extends StatelessWidget {
  const _MarketingConfirmationDialog({required this.opportunity});

  final MarketingOpportunityRequest opportunity;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Send to Marketing?'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this inventory opportunity with the Personalized '
              'Marketing component?',
            ),
            const SizedBox(height: 16),
            _SummaryRow(label: 'Product', value: opportunity.productName),
            _SummaryRow(label: 'Store', value: opportunity.storeId),
            _SummaryRow(
              label: 'Current Stock',
              value: '${opportunity.currentStock} units',
            ),
            _SummaryRow(
              label: 'Forecast Demand',
              value: '${opportunity.forecastDemand} units',
            ),
            _SummaryRow(label: 'Stock Health', value: opportunity.stockHealth),
            if (opportunity.promotionPercent != null)
              _SummaryRow(
                label: 'Promotion Scenario',
                value: '${_percentage(opportunity.promotionPercent!)}%',
              ),
            const SizedBox(height: 14),
            Text(
              'This sends the opportunity for marketing analysis only.\n'
              'No promotion or campaign will be created automatically.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        child: const Text('Send to Marketing'),
      ),
    ],
  );
}

String _percentage(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toString();

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

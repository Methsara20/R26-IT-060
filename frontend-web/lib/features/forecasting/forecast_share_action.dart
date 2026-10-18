import 'package:flutter/material.dart';
import '../../core/auth/inventory_session_controller.dart';
import '../../core/auth/inventory_ui_permissions.dart';
import '../../models/workflow/decision_workflow.dart';
import '../../services/inventory_forecast_sharing_api_service.dart';
import '../../services/inventory_auth_api_service.dart';

class ForecastShareAction extends StatefulWidget {
  const ForecastShareAction({
    super.key,
    required this.workflow,
    required this.session,
    required this.service,
    this.productName,
    this.storeName,
  });
  final DecisionWorkflow workflow;
  final InventorySessionController session;
  final InventoryForecastSharingApiService service;
  final String? productName;
  final String? storeName;
  @override
  State<ForecastShareAction> createState() => _ForecastShareActionState();
}

class _ForecastShareActionState extends State<ForecastShareAction> {
  bool _busy = false;
  bool _sending = false;
  bool _shared = false;
  String? _message;
  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  bool get _permitted {
    final user = widget.session.user;
    return user != null &&
        InventoryUiPermissions(
          user,
        ).canForStores(InventoryOperation.forecast, [widget.workflow.storeId]);
  }

  Future<void> _share() async {
    if (_busy || _shared || !_permitted || !widget.workflow.canShareForecast) {
      return;
    }
    final session = widget.session;
    final workflow = widget.workflow;
    final service = widget.service;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final lease = session.capture();
      final preview = workflow.sharePreview!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Share forecast with Marketing?'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detail(
                    'Product',
                    '${widget.productName ?? workflow.productId} (${workflow.productId})',
                  ),
                  _detail(
                    'Showroom',
                    '${widget.storeName ?? workflow.storeId} (${workflow.storeId})',
                  ),
                  _detail(
                    'Forecast period',
                    '${_date(preview.start!)} to ${_date(preview.end!)}',
                  ),
                  _detail(
                    'Forecast demand',
                    preview.demand?.toString() ?? 'Unavailable',
                  ),
                  _detail(
                    'Available stock snapshot',
                    preview.stock?.toString() ?? 'Unavailable',
                  ),
                  _detail(
                    'Promotion recommendation',
                    workflow.intelligence?.recommendedAction == 'PROMOTE'
                        ? 'Promote'
                        : 'Not provided',
                  ),
                  const Text(
                    'The saved workflow snapshot will be shared. This does not create a campaign or change stock.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm Share'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (!session.isCurrent(lease) ||
          !_permitted ||
          widget.workflow.id != workflow.id) {
        setState(
          () => _message =
              'The session or workflow changed. Sign in and select the forecast again.',
        );
        return;
      }
      setState(() => _sending = true);
      await service.share(workflow.id, confirmed: true);
      if (!mounted || !session.isCurrent(lease)) return;
      setState(() {
        _shared = true;
        _message = 'Forecast shared or already shared.';
      });
    } on ForecastSharingException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on InventoryAuthException catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _sending = false;
        });
      }
    }
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label\n',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.session,
    builder: (context, _) {
      if (!_permitted) return const SizedBox.shrink();
      if (!widget.workflow.canShareForecast) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Sharing requires a completed Daily, 7-Day or Custom forecast with a valid stored workflow reference.',
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: _busy || _shared ? null : _share,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(_sending ? 'Sharing...' : 'Share with Marketing'),
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(liveRegion: true, child: Text(_message!)),
              ),
          ],
        ),
      );
    },
  );
}

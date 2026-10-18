import 'package:flutter/material.dart';

import '../theme/application_design_tokens.dart';
import 'application_ui_components.dart';

enum ApplicationNoticeTone { information, success, warning, danger }

class ApplicationInlineNotice extends StatelessWidget {
  const ApplicationInlineNotice({
    required this.title,
    this.message,
    this.tone = ApplicationNoticeTone.information,
    this.action,
    super.key,
  });

  final String title;
  final String? message;
  final ApplicationNoticeTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (tone) {
      ApplicationNoticeTone.information => (
        ApplicationColors.status(context, ApplicationStatusColor.information),
        Icons.info_outline,
      ),
      ApplicationNoticeTone.success => (
        ApplicationColors.status(context, ApplicationStatusColor.success),
        Icons.check_circle_outline,
      ),
      ApplicationNoticeTone.warning => (
        ApplicationColors.status(context, ApplicationStatusColor.warning),
        Icons.warning_amber_rounded,
      ),
      ApplicationNoticeTone.danger => (
        ApplicationColors.status(context, ApplicationStatusColor.danger),
        Icons.error_outline,
      ),
    };
    return Semantics(
      container: true,
      liveRegion: tone == ApplicationNoticeTone.danger,
      child: Container(
        padding: const EdgeInsets.all(ApplicationSpacing.medium),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(ApplicationRadii.control),
          border: Border.all(color: color.withValues(alpha: .28)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: ApplicationSpacing.compact),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: ApplicationSpacing.xSmall),
                    Text(message!),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: ApplicationSpacing.compact),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class ApplicationErrorState extends StatelessWidget {
  const ApplicationErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => ApplicationEmptyState(
    icon: Icons.cloud_off_outlined,
    title: title,
    message: message,
    action: onRetry == null
        ? null
        : FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(retryLabel),
          ),
  );
}

class ApplicationLoadingSkeleton extends StatefulWidget {
  const ApplicationLoadingSkeleton({
    this.height = 16,
    this.width,
    this.borderRadius = ApplicationRadii.control,
    super.key,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<ApplicationLoadingSkeleton> createState() =>
      _ApplicationLoadingSkeletonState();
}

class _ApplicationLoadingSkeletonState extends State<ApplicationLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading',
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final base = ApplicationColors.panelMuted(context);
        final highlight = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .08);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + controller.value * 3, 0),
              end: Alignment(-.5 + controller.value * 3, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    ),
  );
}

Future<bool> showApplicationConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Cancel',
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ) ??
    false;

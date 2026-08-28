// Shared page layout standardizes content width, headers, utility actions, and
// section-heading rhythm across all primary application modules.
import 'package:flutter/material.dart';

/// Shared alignment grid for every primary application module.
class ApplicationPageContainer extends StatelessWidget {
  const ApplicationPageContainer({
    required this.child,
    this.maxWidth = 1220,
    super.key,
  });


  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

/// Consistent title, subtitle, and optional action layout for primary pages.
class ApplicationPageHeader extends StatelessWidget {
  const ApplicationPageHeader({
    required this.title,
    required this.subtitle,
    this.contextual,
    this.updatedText,
    this.onRefresh,
    this.refreshing = false,
    this.refreshTooltip = 'Refresh data',
    this.actions = const [],
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? contextual;
  final String? updatedText;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final String refreshTooltip;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 20,
    runSpacing: 14,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
      if (contextual != null ||
          updatedText != null ||
          onRefresh != null ||
          actions.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ?contextual,
            if (updatedText != null)
              Text(updatedText!, style: Theme.of(context).textTheme.bodySmall),
            ...actions,
            if (onRefresh != null)
              IconButton.filledTonal(
                onPressed: refreshing ? null : onRefresh,
                tooltip: refreshTooltip,
                icon: refreshing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
          ],
        )
      else
        const SizedBox(width: 42, height: 42),
    ],
  );
}

/// Shared heading rhythm for major sections without changing their content.
class ApplicationSectionHeader extends StatelessWidget {
  const ApplicationSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: 12), trailing!],
    ],
  );
}

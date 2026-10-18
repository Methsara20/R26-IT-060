// Shared page layout standardizes content width, headers, utility actions, and
// section-heading rhythm across all primary application modules.
import 'package:flutter/material.dart';

import '../theme/application_design_tokens.dart';

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
    this.contextLabel,
    this.leadingIcon,
    this.premium = false,
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
  final String? contextLabel;
  final IconData? leadingIcon;
  final bool premium;

  @override
  Widget build(BuildContext context) => premium
      ? _premiumHeader(context)
      : Wrap(
          spacing: ApplicationSpacing.comfortable,
          runSpacing: ApplicationSpacing.compact,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: ApplicationSpacing.small),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
            if (contextual != null ||
                updatedText != null ||
                onRefresh != null ||
                actions.isNotEmpty)
              Wrap(
                spacing: ApplicationSpacing.small,
                runSpacing: ApplicationSpacing.small,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ?contextual,
                  if (updatedText != null)
                    Text(
                      updatedText!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
  Widget _premiumHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contextLabel != null && contextLabel!.isNotEmpty) ...[
              Text(
                contextLabel!.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leadingIcon != null) ...[
                  ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(
                          ApplicationRadii.card,
                        ),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: .12),
                        ),
                      ),
                      child: Icon(leadingIcon, color: scheme.primary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: narrow ? 28 : 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
        final hasUtilities =
            contextual != null ||
            updatedText != null ||
            actions.isNotEmpty ||
            onRefresh != null;
        final utilities = Column(
          crossAxisAlignment: narrow
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.end,
          children: [
            if (updatedText != null) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      updatedText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ?contextual,
                ...actions,
                if (onRefresh != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      backgroundColor: scheme.surface,
                      side: BorderSide(color: scheme.outlineVariant),
                    ),
                    onPressed: refreshing ? null : onRefresh,
                    icon: refreshing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 20),
                    label: Text(refreshing ? 'Refreshing?' : refreshTooltip),
                  ),
              ],
            ),
          ],
        );
        return Container(
          padding: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    if (hasUtilities) ...[
                      const SizedBox(height: 20),
                      utilities,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: heading),
                    if (hasUtilities) ...[
                      const SizedBox(width: 32),
                      Flexible(flex: 2, child: utilities),
                    ],
                  ],
                ),
        );
      },
    );
  }
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
              const SizedBox(height: ApplicationSpacing.xSmall),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
      if (trailing != null) ...[
        const SizedBox(width: ApplicationSpacing.compact),
        trailing!,
      ],
    ],
  );
}

// Shared presentation primitives standardize recurring cards, filters, empty
// states, and semantic badges across the seven primary application modules.
import 'package:flutter/material.dart';

import '../theme/application_design_tokens.dart';

class ApplicationStatCard extends StatelessWidget {
  const ApplicationStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.supportingText,
    this.showAccentBar = true,
    super.key,
  });


  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? supportingText;
  final bool showAccentBar;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(ApplicationSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: .45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(ApplicationRadii.control),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Tooltip(
            message: supportingText ?? value,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ApplicationTypography.data(
                context,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 4),
            Text(
              supportingText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (showAccentBar) ...[
            const SizedBox(height: 14),
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class ApplicationFilterBar extends StatelessWidget {
  const ApplicationFilterBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(ApplicationSpacing.medium),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    ),
  );
}

class ApplicationFilterDropdown extends StatelessWidget {
  const ApplicationFilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 210,
    super.key,
  });

  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: items.containsKey(value) ? value : items.keys.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final item in items.entries)
          DropdownMenuItem(value: item.key, child: Text(item.value)),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class ApplicationEmptyState extends StatelessWidget {
  const ApplicationEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ApplicationSpacing.large,
        vertical: 48,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(ApplicationRadii.card),
              ),
              child: Icon(
                icon,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}

enum ApplicationStatusTone { neutral, info, success, warning, danger }

class ApplicationStatusBadge extends StatelessWidget {
  const ApplicationStatusBadge({
    required this.label,
    this.tone = ApplicationStatusTone.neutral,
    this.icon,
    this.color,
    super.key,
  });

  final String label;
  final ApplicationStatusTone tone;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final semanticColor =
        color ??
        switch (tone) {
          ApplicationStatusTone.neutral => Theme.of(
            context,
          ).colorScheme.onSurfaceVariant,
          ApplicationStatusTone.info => Theme.of(context).colorScheme.primary,
          ApplicationStatusTone.success => ApplicationColors.success,
          ApplicationStatusTone.warning => ApplicationColors.warning,
          ApplicationStatusTone.danger => Theme.of(context).colorScheme.error,
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: semanticColor.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(ApplicationRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: semanticColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: semanticColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ApplicationDataText extends StatelessWidget {
  const ApplicationDataText(
    this.value, {
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String value;
  final double? fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(
    value,
    maxLines: maxLines,
    overflow: overflow,
    style: ApplicationTypography.data(
      context,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    ),
  );
}

/// Reserved surface treatment for content generated or reasoned about by AI.
class ApplicationAiPanel extends StatelessWidget {
  const ApplicationAiPanel({
    required this.child,
    this.padding = const EdgeInsets.all(ApplicationSpacing.medium),
    this.borderRadius = ApplicationRadii.card,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final ai = ApplicationColors.ai(context);
    return Container(
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ai.withValues(alpha: .72), ai.withValues(alpha: .18)],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: ai.withValues(alpha: .08),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: ApplicationColors.panel(context),
        borderRadius: BorderRadius.circular(borderRadius - 1),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Slow pulse used only for live/ready state indicators.
class ApplicationLivePulse extends StatefulWidget {
  const ApplicationLivePulse({this.color, this.size = 8, super.key});

  final Color? color;
  final double size;

  @override
  State<ApplicationLivePulse> createState() => _ApplicationLivePulseState();
}

class _ApplicationLivePulseState extends State<ApplicationLivePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: .72,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color ?? Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (widget.color ?? Theme.of(context).colorScheme.primary)
                .withValues(alpha: .32),
            blurRadius: 6,
          ),
        ],
      ),
    ),
  );
}

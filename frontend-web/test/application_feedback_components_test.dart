import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/core/widgets/application_feedback_components.dart';

void main() {
  Widget app(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: Scaffold(body: child),
  );

  testWidgets('notice and skeleton render in light and dark modes', (
    tester,
  ) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        app(
          const Column(
            children: [
              ApplicationInlineNotice(
                title: 'Saved',
                message: 'The change is ready.',
                tone: ApplicationNoticeTone.success,
              ),
              ApplicationLoadingSkeleton(width: 180),
            ],
          ),
          mode: mode,
        ),
      );
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('error retry and confirmation return expected results', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Column(
            children: [
              ApplicationErrorState(
                title: 'Unavailable',
                message: 'Try the request again.',
                onRetry: () => retried = true,
              ),
              FilledButton(
                onPressed: () async {
                  await showApplicationConfirmationDialog(
                    context,
                    title: 'Continue?',
                    message: 'Review this action.',
                  );
                },
                child: const Text('Open confirmation'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    expect(find.text('Continue?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Continue?'), findsNothing);
  });
}

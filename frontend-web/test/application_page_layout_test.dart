import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/core/widgets/application_page_layout.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      testWidgets('premium header at $width dark=$dark wraps and refreshes', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var refreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ApplicationPageHeader(
                  premium: true,
                  contextLabel: 'Inventory workspace',
                  leadingIcon: Icons.dashboard_outlined,
                  title: 'Dashboard with a deliberately long descriptive title',
                  subtitle:
                      'Monitor inventory health, demand risk and stock-flow decisions across authorized showrooms.',
                  updatedText:
                      'Updated 2026-10-17 12:34 ? last successful inventory summary',
                  contextual: const Text('Current inventory'),
                  actions: [
                    TextButton(onPressed: () {}, child: const Text('Details')),
                  ],
                  onRefresh: () => refreshes++,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('INVENTORY WORKSPACE'), findsOneWidget);
        expect(find.textContaining('2026-10-17 12:34'), findsOneWidget);
        await tester.tap(find.text('Refresh data'));
        expect(refreshes, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('premium refresh supports keyboard focus and disabled loading', (
    tester,
  ) async {
    var count = 0;
    Widget app(bool busy) => MaterialApp(
      home: Scaffold(
        body: ApplicationPageHeader(
          premium: true,
          title: 'Dashboard',
          subtitle: 'Summary',
          refreshing: busy,
          onRefresh: () => count++,
          refreshTooltip: 'Refresh dashboard',
        ),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final button = find.byType(OutlinedButton);
    expect(
      Focus.of(tester.element(find.text('Refresh dashboard'))).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(count, 1);
    await tester.pumpWidget(app(true));
    expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
    expect(find.text('Refreshing?'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(count, 1);
  });

  testWidgets('legacy callers retain wrap layout and icon refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplicationPageHeader(
            title: 'Analytics',
            subtitle: 'Existing description',
            updatedText: 'Existing time',
            onRefresh: () {},
            contextual: const Text('Context'),
            actions: [
              TextButton(onPressed: () {}, child: const Text('Export')),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.text('Context'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Existing time'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });
  testWidgets('shared page header remains readable at a narrow dark width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(460, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Scaffold(
          body: ApplicationPageContainer(
            child: ApplicationPageHeader(
              title: 'Analytics',
              subtitle:
                  'Analyze inventory performance, stock health and business opportunities',
              actions: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Analytics'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });
}

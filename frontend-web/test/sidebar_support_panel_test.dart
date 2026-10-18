import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/shell/widgets/sidebar_support_panel.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('footer follows $brightness and supports enlarged text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: SizedBox(
                width: 272,
                child: SidebarSupportPanel(
                  themeMode: brightness == Brightness.dark
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  onThemeModeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Optimize. Balance. Grow.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('shows mission, local clock, and changes theme mode', (
    tester,
  ) async {
    ThemeMode? selectedMode;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: SidebarSupportPanel(
              themeMode: ThemeMode.light,
              onThemeModeChanged: (mode) => selectedMode = mode,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Optimize. Balance. Grow.'), findsOneWidget);
    expect(find.text('Research prototype • PP2'), findsNothing);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'\d{2}:\d{2}:\d{2} (AM|PM)')),
      findsOneWidget,
    );

    await tester.tap(find.byType(Switch));
    expect(selectedMode, ThemeMode.dark);

    // Advancing time exercises the isolated periodic timer before disposal.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact footer keeps theme control and omits optional details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 272,
            child: SidebarSupportPanel(
              compact: true,
              themeMode: ThemeMode.light,
              onThemeModeChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Light Mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Optimize. Balance. Grow.'), findsNothing);
    expect(find.byType(SidebarClock), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

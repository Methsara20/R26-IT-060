import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/shell/widgets/sidebar_support_panel.dart';

void main() {
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
}

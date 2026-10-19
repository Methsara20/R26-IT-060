import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/core/theme/application_design_tokens.dart';
import 'package:smart_inventory_web/core/widgets/application_ui_components.dart';

void main() {
  Widget app(Widget child, {ThemeMode mode = ThemeMode.light}) => MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: mode,
    home: Scaffold(body: child),
  );

  testWidgets('responsive grid reflows without overflow', (tester) async {
    for (final width in <double>[375, 768, 1024, 1440]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        app(
          ApplicationResponsiveGrid(
            children: List.generate(
              4,
              (index) => ApplicationSurfaceCard(child: Text('Card $index')),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Card 3'), findsOneWidget);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('interactive card supports keyboard activation and semantics', (
    tester,
  ) async {
    var presses = 0;
    await tester.pumpWidget(
      app(
        Center(
          child: ApplicationInteractiveCard(
            semanticLabel: 'Open report',
            onPressed: () => presses++,
            child: const Text('Report'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Report'));
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 2);
    expect(find.bySemanticsLabel('Open report'), findsOneWidget);
  });

  testWidgets('semantic surfaces use dark tokens', (tester) async {
    await tester.pumpWidget(
      app(
        const ApplicationSurfaceCard(child: Text('Dark surface')),
        mode: ThemeMode.dark,
      ),
    );
    final container = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Dark surface'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, ApplicationColors.darkPanel);
  });
}

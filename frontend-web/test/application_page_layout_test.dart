import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/theme/app_theme.dart';
import 'package:smart_inventory_web/core/widgets/application_page_layout.dart';

void main() {
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

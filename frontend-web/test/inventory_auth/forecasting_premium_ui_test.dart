import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/forecasting/forecast_selection_summary.dart';
import 'package:smart_inventory_web/features/forecasting/forecast_type_selector.dart';

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets('premium forecast controls fit at $width in $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        ForecastMode? selected;
        var generated = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2563EB),
                brightness: brightness,
              ),
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ForecastTypeSelector(
                      selectedMode: ForecastMode.daily,
                      onChanged: (mode) => selected = mode,
                    ),
                    const SizedBox(height: 20),
                    ForecastSelectionSummary(
                      showroom: 'Colombo Premium Experience Showroom (CP004)',
                      product:
                          'Long descriptive seasonal inventory product (P0025)',
                      forecastType: 'Custom',
                      sellingPrice: 'LKR 12,500.00',
                      promotion: '10%',
                      dateRange: '2026-10-20 – 2026-10-31',
                      submitting: false,
                      onGenerate: () => generated++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(find.text('Choose forecast horizon'), findsOneWidget);
        expect(find.text('OPERATIONAL'), findsNWidgets(3));
        expect(find.text('STRATEGIC'), findsNWidgets(2));
        expect(find.text('Generate forecast'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(find.text('Quarterly'));
        await tester.tap(find.text('Quarterly'));
        expect(selected, ForecastMode.quarterly);

        await tester.ensureVisible(find.text('Generate forecast'));
        await tester.tap(find.text('Generate forecast'));
        expect(generated, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('generating state disables duplicate submission', (tester) async {
    var generated = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForecastSelectionSummary(
            showroom: 'Colombo (CP004)',
            product: 'Product (P0025)',
            forecastType: 'Daily',
            sellingPrice: 'LKR 1000',
            promotion: '0%',
            submitting: true,
            onGenerate: () => generated++,
          ),
        ),
      ),
    );

    expect(find.text('Generating forecast…'), findsOneWidget);
    await tester.tap(find.text('Generating forecast…'));
    expect(generated, 0);
  });
}

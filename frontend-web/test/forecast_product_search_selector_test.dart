import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/features/forecasting/forecast_product_search_selector.dart';
import 'package:smart_inventory_web/models/forecast/forecast_catalog_option.dart';

void main() {
  const product = ForecastProductOption(
    id: 'P0017',
    name: 'Hustle Shirts Coral',
    sellingPrice: 1135.58,
    category: 'Shirts',
    brand: 'Hustle',
    gender: 'Men',
  );

  testWidgets('selects a product from the product picker dialog', (
    tester,
  ) async {
    ForecastProductOption? selectedProduct;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            child: ForecastProductSearchSelector(
              products: const [product],
              selectedProduct: selectedProduct,
              onChanged: (value) => selectedProduct = value,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();

    expect(find.text('Select product'), findsOneWidget);
    expect(find.text('Hustle Shirts Coral'), findsOneWidget);

    await tester.tap(find.text('Hustle Shirts Coral'));
    await tester.pumpAndSettle();

    expect(selectedProduct?.id, 'P0017');
    expect(find.text('Hustle Shirts Coral (P0017)'), findsOneWidget);
  });
}

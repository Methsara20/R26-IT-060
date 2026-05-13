import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Selection page shows client and store options',
      (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    expect(find.text('Client'), findsOneWidget);
    expect(find.text('Store'), findsOneWidget);
  });

  testWidgets('Navigate to Client page', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    await tester.tap(find.text('Client'));
    await tester.pumpAndSettle();

    expect(find.text('Client Mode'), findsOneWidget);
    expect(find.text('This is the client interface'), findsOneWidget);
  });

  testWidgets('Navigate to Store page', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp());

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();

    expect(find.text('Store Mode'), findsOneWidget);
    expect(find.text('This is the store interface'), findsOneWidget);
  });
}
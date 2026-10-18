import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/core/auth/inventory_api_client.dart';
import 'package:smart_inventory_web/core/auth/inventory_session_controller.dart';
import 'package:smart_inventory_web/features/assistant/manager_assistant_screen.dart';
import 'package:smart_inventory_web/features/workflow/inventory_decision_workflow_controller.dart';
import 'package:smart_inventory_web/models/assistant/manager_chat.dart';
import 'package:smart_inventory_web/models/stock_movement/stock_movement.dart';
import 'package:smart_inventory_web/services/inventory_auth_api_service.dart';
import 'package:smart_inventory_web/services/manager_assistant_api_service.dart';
import 'package:smart_inventory_web/services/stock_movement_api_service.dart';

class _AssistantApi extends ManagerAssistantApiService {
  var sessionLoads = 0;

  @override
  Future<List<ManagerChatSession>> getSessions({int limit = 20}) async {
    sessionLoads++;
    return const [
      ManagerChatSession(
        sessionId: 'CHAT-1',
        title: 'Weekly inventory priorities',
        messageCount: 3,
        mode: 'GENERAL',
      ),
    ];
  }
}

class _MovementApi extends StockMovementApiService {
  _MovementApi()
    : super(
        client: InventoryApiClient(
          session: InventorySessionController(
            api: InventoryAuthApiService(baseUrl: 'http://localhost:8000'),
          ),
        ),
      );

  @override
  Future<List<StockMovement>> getMovements() async => const [];
}

Widget _app({
  required double width,
  required Brightness brightness,
  required _AssistantApi api,
}) {
  final theme = brightness == Brightness.dark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 1000)),
      child: Scaffold(
        body: SingleChildScrollView(
          child: ManagerAssistantScreen(
            workflowController: InventoryDecisionWorkflowController(),
            api: api,
            movementApi: _MovementApi(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets(
        'premium assistant renders at width ${width.toInt()} in ${brightness.name}',
        (tester) async {
          tester.view.physicalSize = Size(width, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final api = _AssistantApi();

          await tester.pumpWidget(
            _app(width: width, brightness: brightness, api: api),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));

          expect(find.text('Manager Assistant'), findsOneWidget);
          expect(find.text('INVENTORY AI'), findsWidgets);
          expect(find.text('What can I help you analyze?'), findsOneWidget);
          if (width < 820) {
            expect(find.byTooltip('Open conversation history'), findsOneWidget);
          } else {
            expect(find.text('Recent chats'), findsOneWidget);
          }
          expect(api.sessionLoads, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('refresh retains workspace and reloads assistant context', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _AssistantApi();

    await tester.pumpWidget(
      _app(width: 1024, brightness: Brightness.light, api: api),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Refresh assistant context'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(api.sessionLoads, 2);
    expect(find.text('What can I help you analyze?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

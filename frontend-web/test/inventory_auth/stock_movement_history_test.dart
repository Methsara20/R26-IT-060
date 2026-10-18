import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_inventory_web/models/stock_movement/stock_movement.dart';
import 'package:smart_inventory_web/features/stock_movements/stock_movements_screen.dart';

Map<String, dynamic> event({String status = 'APPROVED'}) => {
  'status': status,
  'time': '2026-01-02T10:30:00Z',
  'actor_id': 'oid:0123456789abcdef01234567',
  'actor_username_snapshot': 'savedusername',
  'actor_display_name_snapshot': 'Saved Display Name',
  'actor_role_snapshot': 'manager',
  'remarks': 'Saved remark',
};
void main() {
  test('optional snapshots preserve legacy parsing and timestamps', () {
    final original = event();
    final parsed = MovementStatusEvent.fromJson(original);
    expect(parsed.actorId, original['actor_id']);
    expect(parsed.actorUsernameSnapshot, 'savedusername');
    expect(parsed.actorDisplayNameSnapshot, 'Saved Display Name');
    expect(parsed.actorRoleSnapshot, 'manager');
    expect(parsed.time, DateTime.parse(original['time'] as String));
    final legacy = MovementStatusEvent.fromJson({
      'status': 'RECOMMENDED',
      'time': '2020-01-01',
    });
    expect(legacy.actorName, isNull);
    expect(legacy.time, DateTime(2020));
    expect(legacy.status, 'RECOMMENDED');
  });
  for (final status in [
    'RECOMMENDED',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
    'IN_PROGRESS',
    'EXECUTED',
    'FAILED',
  ]) {
    testWidgets('$status shows saved actor, role, timestamp and remarks', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovementHistoryEventTile(
              event: MovementStatusEvent.fromJson(event(status: status)),
            ),
          ),
        ),
      );
      expect(find.text('Saved Display Name'), findsOneWidget);
      expect(find.text('Role: Manager'), findsOneWidget);
      expect(find.text('Saved remark'), findsOneWidget);
      expect(find.text('savedusername'), findsNothing);
      expect(
        find.text(
          status
              .split('_')
              .map((s) => s[0] + s.substring(1).toLowerCase())
              .join(' '),
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('username fallback and unreliable identity legacy fallback', (
    tester,
  ) async {
    for (final fields in [
      {...event(), 'actor_display_name_snapshot': null},
      {
        ...event(),
        'actor_display_name_snapshot': ' ',
        'actor_username_snapshot': null,
      },
      {...event(), 'actor_id': 'invalid'},
      {'status': 'APPROVED', 'time': '2020-01-01'},
    ]) {
      final parsed = MovementStatusEvent.fromJson(fields);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MovementHistoryEventTile(event: parsed)),
        ),
      );
      expect(
        find.text(parsed.actorName ?? 'Actor unavailable \u2014 Legacy record'),
        findsOneWidget,
      );
    }
  });
  testWidgets(
    'long snapshots wrap on small screens without changing event order',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final events = ['RECOMMENDED', 'APPROVED', 'EXECUTED']
          .map(
            (status) => MovementStatusEvent.fromJson({
              ...event(status: status),
              'actor_display_name_snapshot':
                  'A very long historical display name for a narrow screen',
            }),
          )
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: events
                    .map((e) => MovementHistoryEventTile(event: e))
                    .toList(),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.text('Recommended')).dy,
        lessThan(tester.getTopLeft(find.text('Approved')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Approved')).dy,
        lessThan(tester.getTopLeft(find.text('Executed')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

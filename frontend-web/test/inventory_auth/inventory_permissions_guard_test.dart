import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smart_inventory_web/models/auth/inventory_user.dart';
import 'package:smart_inventory_web/core/auth/inventory_ui_permissions.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_scope.dart';
import 'package:smart_inventory_web/core/auth/inventory_auth_guard.dart';
import 'auth_test_support.dart';

void main() {
  final expected = {
    InventoryOperation.readCandidates: 'admin manager analyst operator viewer',
    InventoryOperation.readMovements: 'admin manager analyst operator viewer',
    InventoryOperation.readExplainContext:
        'admin manager analyst operator viewer',
    InventoryOperation.forecast: 'admin manager analyst',
    InventoryOperation.intelligence: 'admin manager analyst',
    InventoryOperation.recommendations: 'admin manager analyst',
    InventoryOperation.analyzeCandidate: 'admin manager analyst',
    InventoryOperation.recommendMovement: 'admin manager analyst',
    InventoryOperation.approveMovement: 'admin manager',
    InventoryOperation.rejectMovement: 'admin manager',
    InventoryOperation.cancelMovement: 'admin manager',
    InventoryOperation.executeMovement: 'admin operator',
    InventoryOperation.explainMovement: 'admin manager analyst',
    InventoryOperation.executionSummary: 'admin manager analyst operator',
    InventoryOperation.readMarketingRequests: 'admin manager analyst',
    InventoryOperation.decideMarketingRequests: 'admin manager',
  };
  for (final role in InventoryRole.values) {
    test('backend operation matrix for ${role.name}', () {
      final policy = InventoryUiPermissions(
        InventoryUser.fromJson(userJson(role: role.name, global: true)),
      );
      for (final operation in InventoryOperation.values) {
        expect(
          policy.can(operation),
          expected[operation]!.split(' ').contains(role.name),
          reason: operation.name,
        );
      }
    });
  }

  test('Admin is not implicitly global and both stores are required', () {
    final policy = InventoryUiPermissions(InventoryUser.fromJson(userJson()));
    expect(policy.canAccessGlobalReports, isFalse);
    expect(policy.can(InventoryOperation.analyzeCandidate), isFalse);
    expect(policy.canAccessStores(['S1', 'S2']), isTrue);
    expect(policy.canAccessStores(['S1', 'S3']), isFalse);
    expect(policy.canAccessStores(['S3', 'S2']), isFalse);
    expect(policy.canAccessStores([]), isFalse);
    expect(policy.canAccessStores(['']), isFalse);
    expect(policy.canAccessStores([' S1']), isFalse);
  });

  test('global scope does not override role restrictions', () {
    final viewer = InventoryUiPermissions(
      InventoryUser.fromJson(userJson(role: 'viewer', global: true)),
    );
    expect(viewer.canAccessStores(['S9']), isTrue);
    expect(
      viewer.canForStores(InventoryOperation.executeMovement, ['S9']),
      isFalse,
    );
    expect(viewer.can(InventoryOperation.analyzeCandidate), isFalse);
  });

  testWidgets(
    'guard mounts no protected screen before login and clears on logout',
    (tester) async {
      final pending = Completer<http.Response>();
      final session = sessionWith((_) => pending.future);
      var protectedBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: InventoryAuthScope(
            session: session,
            child: InventoryAuthGuard(
              builder: (_) {
                protectedBuilds++;
                return const Text('protected');
              },
              signedOutBuilder: (_) => const Text('sign in'),
              loadingBuilder: (_) => const Text('checking'),
            ),
          ),
        ),
      );
      expect(find.text('sign in'), findsOneWidget);
      expect(protectedBuilds, 0);
      final login = session.login('fixtureuser', fakePassword);
      await tester.pump();
      expect(find.text('checking'), findsOneWidget);
      pending.complete(loginResponse());
      await login;
      await tester.pump();
      expect(find.text('protected'), findsOneWidget);
      session.logout();
      await tester.pump();
      expect(find.text('protected'), findsNothing);
      expect(find.text('sign in'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('guard denies unavailable role without mounting content', (
    tester,
  ) async {
    final session = sessionWith(
      (_) async => loginResponse(user: userJson(role: 'viewer')),
    );
    await session.login('fixtureuser', fakePassword);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: InventoryAuthScope(
          session: session,
          child: InventoryAuthGuard(
            builder: (_) {
              builds++;
              return const Text('protected');
            },
            signedOutBuilder: (_) => const Text('sign in'),
            isAllowed: (user) =>
                InventoryUiPermissions(user).can(InventoryOperation.forecast),
          ),
        ),
      ),
    );
    expect(find.text('Inventory access denied.'), findsOneWidget);
    expect(builds, 0);
    expect(session.isAuthenticated, isTrue);
    session.logout();
    await tester.pumpWidget(const SizedBox());
  });
}

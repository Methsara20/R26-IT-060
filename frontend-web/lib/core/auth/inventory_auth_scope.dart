import 'package:flutter/widgets.dart';
import 'inventory_session_controller.dart';

/// Owner creates/disposes the controller. Scope never persists credentials.
class InventoryAuthScope extends InheritedNotifier<InventorySessionController> {
  const InventoryAuthScope({
    required InventorySessionController session,
    required super.child,
    super.key,
  }) : super(notifier: session);

  /// Non-listening lookup for constructing screen-owned clients in initState.
  /// The route guard owns session changes and removes signed-out screens.
  static InventorySessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<InventoryAuthScope>();
    if (scope?.notifier == null) {
      throw StateError('InventoryAuthScope is required.');
    }
    return scope!.notifier!;
  }

  static InventorySessionController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<InventoryAuthScope>();
    if (scope?.notifier == null) {
      throw StateError('InventoryAuthScope is required.');
    }
    return scope!.notifier!;
  }
}

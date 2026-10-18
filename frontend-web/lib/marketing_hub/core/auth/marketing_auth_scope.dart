import 'package:flutter/widgets.dart';

import 'marketing_session_controller.dart';

class MarketingAuthScope extends InheritedNotifier<MarketingSessionController> {
  const MarketingAuthScope({
    required MarketingSessionController session,
    required super.child,
    super.key,
  }) : super(notifier: session);

  static MarketingSessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MarketingAuthScope>();
    if (scope?.notifier == null) {
      throw StateError('MarketingAuthScope is required.');
    }
    return scope!.notifier!;
  }

  static MarketingSessionController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MarketingAuthScope>();
    if (scope?.notifier == null) {
      throw StateError('MarketingAuthScope is required.');
    }
    return scope!.notifier!;
  }
}

import 'package:flutter/material.dart';
import '../../models/auth/inventory_user.dart';
import 'inventory_auth_scope.dart';
import 'inventory_session_controller.dart';
import '../../services/inventory_auth_api_service.dart';

/// Lazy builder prevents protected screens from mounting while signed out.
/// Future route owner triggers /me validation explicitly; no network in build.
class InventoryAuthGuard extends StatelessWidget {
  const InventoryAuthGuard({
    required this.builder,
    required this.signedOutBuilder,
    this.loadingBuilder,
    this.isAllowed,
    this.forbiddenBuilder,
    super.key,
  });
  final WidgetBuilder builder;
  final WidgetBuilder signedOutBuilder;
  final WidgetBuilder? loadingBuilder;
  final bool Function(InventoryUser user)? isAllowed;
  final WidgetBuilder? forbiddenBuilder;

  @override
  Widget build(BuildContext context) {
    final session = InventoryAuthScope.of(context);
    if (session.isLoggingIn || session.isValidating) {
      return loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }
    final user = session.user;
    if (user == null) return signedOutBuilder(context);
    if (isAllowed != null && !isAllowed!(user)) {
      return forbiddenBuilder?.call(context) ??
          const Center(child: Text('Inventory access denied.'));
    }
    return builder(context);
  }
}

/// Validates the current account before mounting Inventory screens. Marketing
/// remains outside this scope and retains its existing route and authentication.
class InventoryAuthenticatedRoute extends StatefulWidget {
  const InventoryAuthenticatedRoute({
    required this.session,
    required this.builder,
    super.key,
  });
  final InventorySessionController session;
  final WidgetBuilder builder;

  @override
  State<InventoryAuthenticatedRoute> createState() =>
      _InventoryAuthenticatedRouteState();
}

class _InventoryAuthenticatedRouteState
    extends State<InventoryAuthenticatedRoute> {
  bool _validated = false;
  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _validate());
  }

  Future<void> _validate() async {
    if (!mounted || _pending || !widget.session.isAuthenticated) return;
    setState(() {
      _pending = true;
      _validated = false;
      _error = null;
    });
    try {
      await widget.session.validate();
      if (mounted) setState(() => _validated = true);
    } on InventoryAuthException catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Inventory authentication is unavailable.');
      }
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => InventoryAuthScope(
    session: widget.session,
    child: InventoryAuthGuard(
      signedOutBuilder: (_) => const _InventoryLoginRedirect(),
      loadingBuilder: (_) =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      builder: (context) {
        if (_validated) return widget.builder(context);
        if (_error == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _validate,
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: widget.session.logout,
                    child: const Text('Return to login'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _InventoryLoginRedirect extends StatefulWidget {
  const _InventoryLoginRedirect();
  @override
  State<_InventoryLoginRedirect> createState() =>
      _InventoryLoginRedirectState();
}

class _InventoryLoginRedirectState extends State<_InventoryLoginRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

import 'package:flutter/material.dart';
import '../../core/auth/inventory_api_client.dart';
import '../../core/auth/inventory_auth_scope.dart';
import '../../core/auth/inventory_session_controller.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_feedback_components.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../models/auth/inventory_user.dart';
import '../../services/inventory_profile_api_service.dart';
import '../../services/inventory_user_management_api_service.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({this.client, super.key});
  final InventoryApiClient? client;
  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final InventorySessionController session;
  late final InventoryApiClient client;
  late final InventoryProfileApiService api;
  final name = TextEditingController(),
      current = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  final nameForm = GlobalKey<FormState>(),
      passwordForm = GlobalKey<FormState>();
  InventoryUser? user;
  InventorySessionLease? lease;
  int? revision;
  bool loading = true, busy = false, blocked = false;
  String? message;
  final Set<String> visiblePasswords = {};

  InputDecoration passwordInput(String label) => InputDecoration(
    labelText: label,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    suffixIcon: IconButton(
      tooltip: visiblePasswords.contains(label) ? 'Hide $label' : 'Show $label',
      onPressed: busy
          ? null
          : () => setState(() {
              if (!visiblePasswords.add(label)) visiblePasswords.remove(label);
            }),
      icon: Icon(
        visiblePasswords.contains(label)
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
      ),
    ),
  );
  @override
  void initState() {
    super.initState();
    session = InventoryAuthScope.read(context);
    client = widget.client ?? InventoryApiClient(session: session);
    api = InventoryProfileApiService(client: client, session: session);
    load();
  }

  @override
  void dispose() {
    for (final c in [name, current, password, confirm]) {
      c.dispose();
    }
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> load() async {
    if (!session.isAuthenticated) {
      setState(() => loading = false);
      return;
    }
    final captured = session.capture();
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final result = await api.me();
      if (mounted && session.isCurrent(captured)) {
        setState(() {
          user = result;
          lease = captured;
          name.text = result.displayName;
          revision = null;
          blocked = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = inventoryAccountMessage(e);
          blocked = true;
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save({bool changePassword = false}) async {
    if (!(changePassword ? passwordForm : nameForm).currentState!.validate()) {
      return;
    }
    final captured = session.capture();
    if (changePassword) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change password and sign out?'),
          content: const Text(
            'You will need to sign in again with your new password.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted || !session.isCurrent(captured)) return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (changePassword) {
        await api.changePassword(
          current.text,
          password.text,
          confirm.text,
          revision: revision,
        );
        current.clear();
        password.clear();
        confirm.clear();
      } else {
        final updated = await api.update(name.text.trim(), revision: revision);
        if (mounted && session.isCurrent(captured)) {
          revision = updated;
          await session.validate();
          if (mounted) {
            lease = session.capture();
            user = session.user;
            message = 'Profile updated.';
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          message = inventoryAccountMessage(e);
          blocked = true;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InventoryAuthScope.of(context);
    if (!session.isAuthenticated) {
      return const Center(child: Text('Sign in again to access My Profile.'));
    }
    final visible = lease != null && session.isCurrent(lease!) ? user : null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ApplicationPageContainer(
        maxWidth: 1120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApplicationPageHeader(
              contextLabel: 'INVENTORY ACCOUNT',
              leadingIcon: Icons.account_circle_outlined,
              premium: true,
              title: 'My Profile',
              subtitle:
                  'Manage your personal information and account security.',
              onRefresh: busy || loading ? null : load,
              refreshing: loading,
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: ApplicationInlineNotice(
                  title: blocked
                      ? 'Profile update unavailable'
                      : 'Profile updated',
                  message: message,
                  tone: blocked
                      ? ApplicationNoticeTone.danger
                      : ApplicationNoticeTone.success,
                  action: blocked
                      ? TextButton(
                          onPressed: loading ? null : load,
                          child: const Text('Reload profile'),
                        )
                      : null,
                ),
              ),
            if (loading && visible == null) ...[
              const SizedBox(height: 24),
              const _ProfileLoadingState(),
            ],
            if (visible != null) ...[
              const SizedBox(height: 24),
              _ProfileOverview(user: visible),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final personal = ApplicationSurfaceCard(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: nameForm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionHeading(
                            icon: Icons.manage_accounts_outlined,
                            title: 'Personal information',
                            description:
                                'Update the display name used on new Inventory activity.',
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: name,
                            enabled: !busy && !blocked,
                            decoration: const InputDecoration(
                              labelText: 'Display name',
                              helperText:
                                  'Username, role and access are managed by an administrator.',
                              floatingLabelBehavior:
                                  FloatingLabelBehavior.always,
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) =>
                                v == null ||
                                    v.trim().isEmpty ||
                                    v.length > 128 ||
                                    RegExp(r'[\x00-\x1f]').hasMatch(v)
                                ? 'Enter a valid display name (1-128 characters).'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: busy || blocked ? null : () => save(),
                              icon: busy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                busy ? 'Saving...' : 'Save display name',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  final security = ApplicationSurfaceCard(
                    padding: const EdgeInsets.all(22),
                    child: Form(
                      key: passwordForm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _SectionHeading(
                            icon: Icons.security_outlined,
                            title: 'Password security',
                            description:
                                'Use a unique password of 12-1024 characters.',
                          ),
                          const SizedBox(height: 16),
                          const ApplicationInlineNotice(
                            title: 'Sign-in required after this change',
                            message:
                                'A successful password change ends this session and requires a new login.',
                            tone: ApplicationNoticeTone.warning,
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: current,
                            enabled: !busy && !blocked,
                            obscureText: !visiblePasswords.contains(
                              'Current password',
                            ),
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.password],
                            decoration: passwordInput('Current password'),
                            validator: (v) =>
                                v == null || v.isEmpty || v.length > 1024
                                ? 'Enter your current password.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: password,
                            enabled: !busy && !blocked,
                            obscureText: !visiblePasswords.contains(
                              'New password',
                            ),
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: passwordInput('New password'),
                            validator: (v) =>
                                v == null ||
                                    v.length < 12 ||
                                    v.length > 1024 ||
                                    v == current.text
                                ? 'Use a different password of 12-1024 characters.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: confirm,
                            enabled: !busy && !blocked,
                            obscureText: !visiblePasswords.contains(
                              'Confirm new password',
                            ),
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: passwordInput('Confirm new password'),
                            validator: (v) => v != password.text
                                ? 'Passwords must match.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          LayoutBuilder(
                            builder: (context, constraints) => Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: busy || blocked
                                    ? null
                                    : () => save(changePassword: true),
                                icon: const Icon(Icons.logout_outlined),
                                label: Text(
                                  constraints.maxWidth < 360
                                      ? 'Change password'
                                      : 'Change password and sign out',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        personal,
                        const SizedBox(height: 20),
                        security,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: personal),
                      const SizedBox(width: 20),
                      Expanded(child: security),
                    ],
                  );
                },
              ),
            ] else if (!loading)
              ApplicationEmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile unavailable',
                message: 'Reload your Inventory profile to try again.',
                action: FilledButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload profile'),
                ),
              ),
            if (busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

String _roleLabel(InventoryRole role) => switch (role) {
  InventoryRole.admin => 'Admin',
  InventoryRole.manager => 'Manager',
  InventoryRole.analyst => 'Analyst',
  InventoryRole.operator => 'Operator',
  InventoryRole.viewer => 'Viewer',
};

String _roleDescription(InventoryRole role) => switch (role) {
  InventoryRole.admin => 'Inventory administration',
  InventoryRole.manager => 'Planning and approvals',
  InventoryRole.analyst => 'Forecasts and analysis',
  InventoryRole.operator => 'Transfer execution',
  InventoryRole.viewer => 'Read-only Inventory access',
};

class _ProfileOverview extends StatelessWidget {
  const _ProfileOverview({required this.user});
  final InventoryUser user;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    padding: const EdgeInsets.all(24),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 680;
        final identity = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!narrow) ...[
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 32,
                  child: Text(
                    user.displayName.trim().isEmpty
                        ? '?'
                        : user.displayName.trim()[0].toUpperCase(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${user.username}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ApplicationStatusBadge(
                        label: _roleLabel(user.role),
                        tone: ApplicationStatusTone.info,
                        icon: Icons.badge_outlined,
                      ),
                      const ApplicationStatusBadge(
                        label: 'Authenticated',
                        tone: ApplicationStatusTone.success,
                        icon: Icons.verified_user_outlined,
                      ),
                      ApplicationStatusBadge(
                        label: user.globalAccess
                            ? 'Global Access'
                            : '${user.storeIds.length} assigned ${user.storeIds.length == 1 ? "store" : "stores"}',
                        tone: user.globalAccess
                            ? ApplicationStatusTone.info
                            : ApplicationStatusTone.neutral,
                        icon: user.globalAccess
                            ? Icons.public
                            : narrow
                            ? null
                            : Icons.storefront_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
        final access = _AccessSummary(user: user);
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const Divider(height: 32), access],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 28),
            Expanded(child: access),
          ],
        );
      },
    ),
  );
}

class _AccessSummary extends StatelessWidget {
  const _AccessSummary({required this.user});
  final InventoryUser user;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Inventory account permissions and showroom access',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account access',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text('Role: ${_roleLabel(user.role)} · ${_roleDescription(user.role)}'),
        const SizedBox(height: 12),
        Text(
          user.globalAccess ? 'Showroom access' : 'Assigned showrooms',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (user.globalAccess)
          const Text(
            'All Inventory stores. Available actions remain limited by your role permissions.',
          )
        else if (user.storeIds.isEmpty)
          const Text('No showrooms are assigned to this account.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in user.storeIds)
                ApplicationStatusBadge(label: id, icon: Icons.store_outlined),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Role and showroom access are managed by an Inventory administrator.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ProfileLoadingState extends StatelessWidget {
  const _ProfileLoadingState();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ApplicationLoadingSkeleton(height: 170),
      SizedBox(height: 20),
      Row(
        children: [
          Expanded(child: ApplicationLoadingSkeleton(height: 300)),
          SizedBox(width: 20),
          Expanded(child: ApplicationLoadingSkeleton(height: 300)),
        ],
      ),
    ],
  );
}

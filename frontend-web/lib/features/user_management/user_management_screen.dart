import 'package:flutter/material.dart';
import '../../core/auth/inventory_api_client.dart';
import '../../core/auth/inventory_auth_scope.dart';
import '../../core/auth/inventory_session_controller.dart';
import '../../core/auth/inventory_ui_permissions.dart';
import '../../core/widgets/application_page_layout.dart';
import '../../core/widgets/application_feedback_components.dart';
import '../../core/widgets/application_ui_components.dart';
import '../../services/inventory_user_management_api_service.dart';
import 'widgets/user_form_dialog.dart';
import 'widgets/reset_password_dialog.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({this.client, super.key});
  final InventoryApiClient? client;
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final InventorySessionController session;
  late final InventoryApiClient client;
  late final InventoryUserManagementApiService api;
  final search = TextEditingController();
  InventoryUserPage? page;
  Map<String, String> storeNames = {};
  InventorySessionLease? pageLease;
  int offset = 0, generation = 0;
  bool loading = false, busy = false;
  String? error;
  bool get allowed =>
      session.user != null &&
      InventoryUiPermissions(session.user!).canManageUsers;
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    session = InventoryAuthScope.read(context);
    client = widget.client ?? InventoryApiClient(session: session);
    api = InventoryUserManagementApiService(client: client, session: session);
    if (allowed) {
      load();
      refreshStoreNames();
    }
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    if (widget.client == null) client.close();
    super.dispose();
  }

  Future<void> load() async {
    if (!allowed) return;
    final request = ++generation;
    final lease = session.capture();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await api.list(search: search.text.trim(), offset: offset);
      if (mounted && request == generation && session.isCurrent(lease)) {
        setState(() {
          page = result;
          pageLease = lease;
        });
      }
    } catch (e) {
      if (mounted && request == generation) {
        setState(() => error = inventoryAccountMessage(e));
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> refreshStoreNames() async {
    try {
      final stores = await api.stores();
      if (mounted && allowed) {
        setState(
          () => storeNames = {for (final store in stores) store.id: store.name},
        );
      }
    } catch (_) {
      /* IDs remain visible when the public catalog is unavailable. */
    }
  }

  void success(String text) {
    if (mounted && allowed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> edit([ManagedInventoryUser? account]) async {
    final lease = session.capture();
    setState(() => busy = true);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: session,
        builder: (context, _) => session.isCurrent(lease) && allowed
            ? UserFormDialog(
                loadStores: api.stores,
                account: account,
                isSelf: account?.user.userId == session.user?.userId,
                onSave: (body) async {
                  await api.save(body, id: account?.user.userId);
                },
              )
            : AlertDialog(
                title: const Text('Session changed'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
      ),
    );
    if (mounted) {
      setState(() => busy = false);
      if (saved == true) success('Account change saved.');
      await load();
    }
  }

  Future<void> reset(ManagedInventoryUser account) async {
    final lease = session.capture();
    setState(() => busy = true);
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AnimatedBuilder(
        animation: session,
        builder: (context, _) => session.isCurrent(lease) && allowed
            ? ResetPasswordDialog(
                onReset: (password) async {
                  await api.reset(account, password);
                  if (account.user.userId == session.user?.userId) {
                    session.invalidate(lease);
                  }
                },
              )
            : AlertDialog(
                title: const Text('Sign in again'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
      ),
    );
    if (mounted) {
      setState(() => busy = false);
      if (saved == true) success('Account change saved.');
      await load();
    }
  }

  Future<void> status(ManagedInventoryUser account) async {
    final lease = session.capture();
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account.active ? 'Deactivate user?' : 'Activate user?'),
        content: const Text(
          'Account access will change and existing sessions will be revoked.',
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
    if (yes != true || !mounted || !session.isCurrent(lease) || !allowed) {
      return;
    }
    setState(() => busy = true);
    try {
      await api.status(account);
      success(account.active ? 'User deactivated.' : 'User activated.');
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = inventoryAccountMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    InventoryAuthScope.of(context);
    if (!allowed) {
      return const Center(
        child: Text(
          'Inventory access denied. Global Admin access is required.',
        ),
      );
    }
    final visible = pageLease != null && session.isCurrent(pageLease!)
        ? page
        : null;
    final displayed = visible?.users
        .where(
          (account) =>
              statusFilter == 'All' ||
              (account.active ? 'Active' : 'Inactive') == statusFilter,
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ApplicationPageContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApplicationPageHeader(
              contextLabel: 'INVENTORY ADMINISTRATION',
              leadingIcon: Icons.manage_accounts_outlined,
              premium: true,
              title: 'User Management',
              subtitle: 'Manage Inventory accounts and store access.',
              onRefresh: busy ? null : load,
              refreshing: loading,
              actions: [
                FilledButton.icon(
                  onPressed: busy || loading ? null : () => edit(),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add user'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DirectoryFilters(
              search: search,
              statusFilter: statusFilter,
              disabled: busy || loading,
              onSearch: () {
                offset = 0;
                load();
              },
              onClear: () {
                search.clear();
                offset = 0;
                load();
              },
              onStatusChanged: (value) => setState(() => statusFilter = value),
            ),
            const SizedBox(height: 16),
            if (loading && visible != null)
              const LinearProgressIndicator(minHeight: 2),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ApplicationInlineNotice(
                  title: 'Unable to load Inventory users',
                  message: error,
                  tone: ApplicationNoticeTone.danger,
                  action: TextButton(
                    onPressed: loading ? null : load,
                    child: const Text('Try again'),
                  ),
                ),
              ),
            if (loading && visible == null) const _UserDirectorySkeleton(),
            if (!loading && error == null && visible == null)
              ApplicationEmptyState(
                icon: Icons.group_off_outlined,
                title: 'User directory unavailable',
                message: 'Reload the Inventory user directory to try again.',
                action: FilledButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reload users'),
                ),
              ),
            if (visible != null) ...[
              _DirectorySummary(
                visibleCount: displayed!.length,
                total: visible.total,
                first: visible.users.isEmpty ? 0 : offset + 1,
                last: visible.users.isEmpty ? 0 : offset + visible.users.length,
              ),
              const SizedBox(height: 12),
              if (displayed.isEmpty)
                const ApplicationEmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No users found.',
                  message: 'Try another search or current-page status filter.',
                ),
              ...displayed.map(
                (account) => _UserDirectoryEntry(
                  account: account,
                  storeNames: storeNames,
                  isSelf: account.user.userId == session.user?.userId,
                  disabled: busy || loading,
                  onEdit: () => edit(account),
                  onStatus: () => status(account),
                  onReset: () => reset(account),
                ),
              ),
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('${visible.total} users / Page ${offset ~/ 20 + 1}'),
                  TextButton(
                    onPressed: busy || loading || offset == 0
                        ? null
                        : () {
                            offset -= 20;
                            load();
                          },
                    child: const Text('Previous'),
                  ),
                  TextButton(
                    onPressed:
                        busy ||
                            loading ||
                            offset + 20 >= visible.total ||
                            offset + 20 > 10000
                        ? null
                        : () {
                            offset += 20;
                            load();
                          },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DirectoryFilters extends StatelessWidget {
  const _DirectoryFilters({
    required this.search,
    required this.statusFilter,
    required this.disabled,
    required this.onSearch,
    required this.onClear,
    required this.onStatusChanged,
  });

  final TextEditingController search;
  final String statusFilter;
  final bool disabled;
  final VoidCallback onSearch;
  final VoidCallback onClear;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) => ApplicationSurfaceCard(
    padding: const EdgeInsets.all(20),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 720;
        final searchField = TextField(
          controller: search,
          maxLength: 128,
          enabled: !disabled,
          decoration: InputDecoration(
            labelText: 'Search users',
            hintText: 'Username or display name',
            helperText: 'Searches all Inventory accounts',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: ListenableBuilder(
              listenable: search,
              builder: (context, _) => search.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      onPressed: disabled ? null : onClear,
                      tooltip: 'Clear user search',
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          onSubmitted: disabled ? null : (_) => onSearch(),
        );
        final filters = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status on this page',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in ['All', 'Active', 'Inactive'])
                  ChoiceChip(
                    label: Text(status),
                    selected: statusFilter == status,
                    onSelected: disabled
                        ? null
                        : (_) => onStatusChanged(status),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'This status filter applies only to the 20 accounts loaded on the current page.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (narrow) ...[
              searchField,
              const SizedBox(height: 16),
              filters,
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: searchField),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: filters),
                ],
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: disabled ? null : onSearch,
                icon: const Icon(Icons.search),
                label: const Text('Search directory'),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _DirectorySummary extends StatelessWidget {
  const _DirectorySummary({
    required this.visibleCount,
    required this.total,
    required this.first,
    required this.last,
  });

  final int visibleCount;
  final int total;
  final int first;
  final int last;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        Icons.groups_2_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          '$total Inventory users · Showing $first–$last · $visibleCount match the current-page filter',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _UserDirectoryEntry extends StatelessWidget {
  const _UserDirectoryEntry({
    required this.account,
    required this.storeNames,
    required this.isSelf,
    required this.disabled,
    required this.onEdit,
    required this.onStatus,
    required this.onReset,
  });

  final ManagedInventoryUser account;
  final Map<String, String> storeNames;
  final bool isSelf;
  final bool disabled;
  final VoidCallback onEdit;
  final VoidCallback onStatus;
  final VoidCallback onReset;

  String get scope {
    if (account.user.globalAccess) {
      return 'All Inventory stores, subject to role permissions';
    }
    if (account.user.storeIds.isEmpty) return 'No assigned stores';
    final labels = account.user.storeIds
        .map((id) => '$id - ${storeNames[id] ?? "name unavailable"}')
        .toList();
    if (labels.length <= 3) return labels.join(' · ');
    return '${labels.take(3).join(' · ')} · +${labels.length - 3} more';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ApplicationSurfaceCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 760;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Text(
                  account.user.displayName.trim().isEmpty
                      ? '?'
                      : account.user.displayName.trim()[0].toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.user.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '@${account.user.username}',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final badges = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ApplicationStatusBadge(
                label: inventoryRoleLabel(account.user.role).split(' - ').first,
                tone: ApplicationStatusTone.info,
                icon: Icons.badge_outlined,
              ),
              ApplicationStatusBadge(
                label: account.active ? 'Active' : 'Inactive',
                tone: account.active
                    ? ApplicationStatusTone.success
                    : ApplicationStatusTone.warning,
                icon: account.active
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_outline,
              ),
              if (account.user.globalAccess)
                const ApplicationStatusBadge(
                  label: 'Global Access',
                  tone: ApplicationStatusTone.info,
                  icon: Icons.public,
                ),
              if (isSelf)
                const ApplicationStatusBadge(
                  label: 'Your account',
                  icon: Icons.person_outline,
                ),
            ],
          );
          final access = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.user.globalAccess ? 'Access scope' : 'Assigned stores',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Tooltip(
                message: account.user.globalAccess
                    ? scope
                    : account.user.storeIds
                          .map(
                            (id) =>
                                '$id - ${storeNames[id] ?? "name unavailable"}',
                          )
                          .join('\n'),
                child: Text(scope, maxLines: mobile ? 3 : 2),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: disabled ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              TextButton.icon(
                onPressed: disabled || isSelf ? null : onStatus,
                icon: Icon(
                  account.active
                      ? Icons.person_off_outlined
                      : Icons.person_add_alt_outlined,
                  size: 18,
                ),
                label: Text(account.active ? 'Deactivate' : 'Activate'),
              ),
              TextButton.icon(
                onPressed: disabled ? null : onReset,
                icon: const Icon(Icons.lock_reset_outlined, size: 18),
                label: const Text('Reset password'),
              ),
            ],
          );
          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                const SizedBox(height: 14),
                badges,
                const Divider(height: 28),
                access,
                const Divider(height: 28),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: badges),
                ],
              ),
              const Divider(height: 28),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: access),
                  const SizedBox(width: 20),
                  actions,
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _UserDirectorySkeleton extends StatelessWidget {
  const _UserDirectorySkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      ApplicationLoadingSkeleton(height: 92),
      SizedBox(height: 12),
      ApplicationLoadingSkeleton(height: 132),
      SizedBox(height: 12),
      ApplicationLoadingSkeleton(height: 132),
    ],
  );
}

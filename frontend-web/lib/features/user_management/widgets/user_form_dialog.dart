import 'package:flutter/material.dart';
import '../../../models/auth/inventory_user.dart';
import '../../../services/inventory_user_management_api_service.dart';
import '../../../core/widgets/application_feedback_components.dart';

String inventoryRoleLabel(InventoryRole role) => switch (role) {
  InventoryRole.admin => 'Admin - Inventory administration',
  InventoryRole.manager => 'Manager - Planning and approvals',
  InventoryRole.analyst => 'Analyst - Forecasts and analysis',
  InventoryRole.operator => 'Operator - Transfer execution',
  InventoryRole.viewer => 'Viewer - Read-only access',
};

/// External labels remain readable in both compact and desktop dialogs.
Widget accountField(String label, Widget input) => Padding(
  padding: const EdgeInsets.only(bottom: 18),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      input,
    ],
  ),
);
InputDecoration accountInput({String? hint, Widget? suffix}) => InputDecoration(
  hintText: hint,
  suffixIcon: suffix,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
  errorMaxLines: 3,
);

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    required this.onSave,
    this.loadStores,
    this.account,
    this.isSelf = false,
    super.key,
  });
  final ManagedInventoryUser? account;
  final bool isSelf;
  final Future<List<InventoryStoreChoice>> Function()? loadStores;
  final Future<void> Function(Map<String, dynamic>) onSave;
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final form = GlobalKey<FormState>();
  final username = TextEditingController(), display = TextEditingController();
  final password = TextEditingController(), confirm = TextEditingController();
  final search = TextEditingController();
  final selected = <String>{};
  List<InventoryStoreChoice> choices = [];
  InventoryRole role = InventoryRole.viewer;
  bool global = false, busy = false, failed = false, loadingStores = true;
  bool showPassword = false, showConfirm = false;
  String? error, storeError;
  @override
  void initState() {
    super.initState();
    final user = widget.account?.user;
    if (user != null) {
      username.text = user.username;
      display.text = user.displayName;
      selected.addAll(user.storeIds);
      role = user.role;
      global = user.globalAccess;
    }
    loadStores();
  }

  Future<void> loadStores() async {
    setState(() {
      loadingStores = true;
      storeError = null;
    });
    try {
      if (widget.loadStores == null) throw const InventoryAccountError(503);
      final result = await widget.loadStores!();
      if (mounted) setState(() => choices = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => storeError =
              'Store catalog unavailable. Existing assignments are preserved. Retry to select stores.',
        );
      }
    } finally {
      if (mounted) setState(() => loadingStores = false);
    }
  }

  @override
  void dispose() {
    for (final c in [username, display, password, confirm, search]) {
      c.dispose();
    }
    super.dispose();
  }

  String? text(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          value.length > 128 ||
          RegExp(r'[\x00-\x1f]').hasMatch(value)
      ? 'Enter 1-128 characters without control characters.'
      : null;
  Future<void> save() async {
    if (busy || failed || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave({
        'display_name': display.text.trim(),
        if (widget.account == null) 'username': username.text.trim(),
        if (widget.account == null) 'password': password.text,
        if (widget.account != null) 'revision': widget.account!.revision,
        if (!widget.isSelf) ...{
          'role': role.name,
          'global_access': global,
          'store_ids': global ? <String>[] : selected.toList(),
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = inventoryAccountMessage(e);
          // Validation may be corrected; conflicts and uncertain outcomes require reload.
          failed =
              e is! InventoryAccountError || ![400, 422].contains(e.status);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget section(IconData icon, String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 16, top: 8),
    child: Row(
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
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget pair(Widget first, Widget second) => LayoutBuilder(
    builder: (context, size) => size.maxWidth >= 560
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: 20),
              Expanded(child: second),
            ],
          )
        : Column(children: [first, second]),
  );
  Widget secret(
    TextEditingController controller,
    String label,
    bool visible,
    VoidCallback toggle,
    String? Function(String?) validator,
  ) => accountField(
    label,
    TextFormField(
      key: ValueKey(label),
      controller: controller,
      enabled: !busy,
      obscureText: !visible,
      enableSuggestions: false,
      autocorrect: false,
      decoration: accountInput(
        suffix: IconButton(
          tooltip: visible ? 'Hide $label' : 'Show $label',
          onPressed: busy ? null : toggle,
          icon: Icon(
            visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final matches = choices
        .where((s) => s.label.toLowerCase().contains(search.text.toLowerCase()))
        .toList();
    final names = {for (final s in choices) s.id: s.label};
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        icon: const Icon(Icons.manage_accounts_outlined),
        title: Text(
          widget.account == null ? 'Add Inventory user' : 'Edit Inventory user',
        ),
        content: SizedBox(
          width: 760,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  section(
                    Icons.person_outline,
                    'Account details',
                    'Inventory access only. Other platform accounts are unaffected.',
                  ),
                  pair(
                    accountField(
                      'Username',
                      TextFormField(
                        key: const ValueKey('Username'),
                        controller: username,
                        enabled: widget.account == null && !busy,
                        decoration: accountInput(hint: 'Enter a username'),
                        validator: text,
                      ),
                    ),
                    accountField(
                      'Display name',
                      TextFormField(
                        key: const ValueKey('Display name'),
                        controller: display,
                        enabled: !busy,
                        decoration: accountInput(hint: 'Enter a display name'),
                        validator: text,
                      ),
                    ),
                  ),
                  section(
                    Icons.admin_panel_settings_outlined,
                    'Role and store access',
                    'The backend checks all permissions and store assignments.',
                  ),
                  accountField(
                    'Inventory role',
                    DropdownButtonFormField<InventoryRole>(
                      initialValue: role,
                      isExpanded: true,
                      decoration: accountInput(),
                      items: InventoryRole.values
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(
                                inventoryRoleLabel(r),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy || widget.isSelf
                          ? null
                          : (v) => setState(() => role = v!),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Global Inventory access'),
                    subtitle: const Text(
                      'Access to all stores remains limited by the selected role permissions.',
                    ),
                    value: global,
                    onChanged: busy || widget.isSelf
                        ? null
                        : (v) => setState(() => global = v),
                  ),
                  if (global)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: ApplicationInlineNotice(
                        title: 'Global Inventory scope',
                        message:
                            'All Inventory stores are available, subject to the selected role. No individual store assignments will be submitted.',
                        tone: ApplicationNoticeTone.information,
                      ),
                    ),
                  if (!global)
                    FormField<void>(
                      validator: (_) {
                        if (widget.isSelf) return null;
                        if (loadingStores || storeError != null) {
                          return 'Load the store catalog before saving store assignments.';
                        }
                        if (selected.length > 200 ||
                            (selected.isEmpty &&
                                (widget.account?.active ?? true))) {
                          return 'Select at least one store (maximum 200).';
                        }
                        if (selected.any((id) => !names.containsKey(id))) {
                          return 'Remove unavailable stores before saving.';
                        }
                        return null;
                      },
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned stores',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (selected.isEmpty)
                            const Text('No stores selected.'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: selected
                                .map(
                                  (id) => InputChip(
                                    label: Text(
                                      names[id] ?? '$id - name unavailable',
                                    ),
                                    onDeleted: busy || widget.isSelf
                                        ? null
                                        : () => setState(
                                            () => selected.remove(id),
                                          ),
                                  ),
                                )
                                .toList(),
                          ),
                          if (loadingStores)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: LinearProgressIndicator(),
                            ),
                          if (storeError != null) ...[
                            ApplicationInlineNotice(
                              title: 'Store catalog unavailable',
                              message: storeError,
                              tone: ApplicationNoticeTone.warning,
                              action: TextButton(
                                onPressed: busy ? null : loadStores,
                                child: const Text('Retry stores'),
                              ),
                            ),
                          ],
                          if (!loadingStores &&
                              storeError == null &&
                              !widget.isSelf) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: search,
                              enabled: !busy,
                              onChanged: (_) => setState(() {}),
                              decoration: accountInput(
                                hint: 'Search store ID or name',
                                suffix: const Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (choices.isEmpty)
                              const Text(
                                'No stores available. Ask an administrator to check the catalog.',
                              )
                            else if (matches.isEmpty)
                              const Text('No matching stores.')
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 210,
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: matches
                                      .map(
                                        (store) => CheckboxListTile(
                                          key: ValueKey('store-${store.id}'),
                                          contentPadding: EdgeInsets.zero,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: Text(store.name),
                                          subtitle: Text(store.id),
                                          value: selected.contains(store.id),
                                          onChanged: busy
                                              ? null
                                              : (value) => setState(() {
                                                  if (value == true) {
                                                    selected.add(store.id);
                                                  } else {
                                                    selected.remove(store.id);
                                                  }
                                                }),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                          ],
                          if (field.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  if (widget.isSelf)
                    const ApplicationInlineNotice(
                      title: 'Your administrator account',
                      message:
                          'Your own role and store permissions cannot be changed here.',
                      tone: ApplicationNoticeTone.information,
                    ),
                  if (widget.account == null) ...[
                    section(
                      Icons.password_outlined,
                      'Initial password',
                      'Use 12-1024 characters. Spaces are preserved. Share the password securely.',
                    ),
                    pair(
                      secret(
                        password,
                        'Initial password',
                        showPassword,
                        () => setState(() => showPassword = !showPassword),
                        (v) => v == null || v.length < 12 || v.length > 1024
                            ? 'Use 12-1024 characters.'
                            : null,
                      ),
                      secret(
                        confirm,
                        'Confirm password',
                        showConfirm,
                        () => setState(() => showConfirm = !showConfirm),
                        (v) =>
                            v != password.text ? 'Passwords must match.' : null,
                      ),
                    ),
                  ],
                  if (error != null)
                    ApplicationInlineNotice(
                      title: 'Account could not be saved',
                      message: error,
                      tone: ApplicationNoticeTone.danger,
                    ),
                  if (failed)
                    const Text(
                      'Close this dialog and reload the account before trying again.',
                    ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy || failed ? null : save,
            child: Text(busy ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}

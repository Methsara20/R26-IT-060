import 'package:flutter/material.dart';
import '../../../services/inventory_user_management_api_service.dart';
import '../../../core/widgets/application_feedback_components.dart';
import 'user_form_dialog.dart' show accountField, accountInput;

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({required this.onReset, super.key});
  final Future<void> Function(String) onReset;
  @override
  State<ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<ResetPasswordDialog> {
  final form = GlobalKey<FormState>();
  final password = TextEditingController(),
      confirmation = TextEditingController();
  bool busy = false, failed = false, showPassword = false, showConfirm = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> reset() async {
    if (busy || failed || !form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      await widget.onReset(password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = inventoryAccountMessage(e);
          failed =
              e is! InventoryAccountError || ![400, 422].contains(e.status);
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      icon: const Icon(Icons.lock_reset_outlined),
      title: const Text('Reset user password'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ApplicationInlineNotice(
                  title: 'Security-sensitive action',
                  message:
                      'Resetting this password revokes existing sessions. Share the new password securely.',
                  tone: ApplicationNoticeTone.warning,
                ),
                const SizedBox(height: 16),
                Text(
                  'Password requirements',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text('Use 12-1024 characters. Spaces are preserved.'),
                const SizedBox(height: 24),
                accountField(
                  'New password',
                  TextFormField(
                    controller: password,
                    obscureText: !showPassword,
                    enabled: !busy,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: accountInput(
                      suffix: IconButton(
                        tooltip: showPassword
                            ? 'Hide new password'
                            : 'Show new password',
                        onPressed: busy
                            ? null
                            : () =>
                                  setState(() => showPassword = !showPassword),
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.length < 12 || v.length > 1024
                        ? 'Use 12-1024 characters.'
                        : null,
                  ),
                ),
                accountField(
                  'Confirm password',
                  TextFormField(
                    controller: confirmation,
                    obscureText: !showConfirm,
                    enabled: !busy,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: accountInput(
                      suffix: IconButton(
                        tooltip: showConfirm
                            ? 'Hide confirmation'
                            : 'Show confirmation',
                        onPressed: busy
                            ? null
                            : () => setState(() => showConfirm = !showConfirm),
                        icon: Icon(
                          showConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v != password.text ? 'Passwords must match.' : null,
                  ),
                ),
                if (error != null)
                  ApplicationInlineNotice(
                    title: 'Password could not be reset',
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
          onPressed: busy || failed ? null : reset,
          child: Text(busy ? 'Resetting...' : 'Reset password'),
        ),
      ],
    ),
  );
}

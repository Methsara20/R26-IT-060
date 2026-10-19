import 'package:flutter/material.dart';

import '../core/auth/inventory_auth_scope.dart';
import '../core/theme/application_design_tokens.dart';
import '../services/inventory_auth_api_service.dart';
import '../marketing_hub/core/auth/marketing_auth_scope.dart';
import '../marketing_hub/services/marketing_auth_service.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocus = FocusNode(debugLabel: 'Shared login username');
  final _passwordFocus = FocusNode(debugLabel: 'Shared login password');
  String _errorMessage = '';
  String? _usernameError;
  String? _passwordError;

  bool _submitting = false;
  bool _sessionReady = false;
  bool _hidePassword = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sessionReady) return;
    final session = InventoryAuthScope.of(context);
    final marketingSession = MarketingAuthScope.of(context);
    // Existing shell logout returns here. Clear memory before accepting input.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _sessionReady) return;
      session.logout();
      marketingSession.logout();
      setState(() => _sessionReady = true);
    });
  }

  Future<void> _login() async {
    if (!_sessionReady || _submitting) return;
    final rawUsername = _usernameController.text;
    final username = rawUsername.trim();
    final password = _passwordController.text;
    final session = InventoryAuthScope.of(context);
    final marketingSession = MarketingAuthScope.of(context);

    final usernameMissing = username.isEmpty;
    final passwordMissing = password.isEmpty;
    if (usernameMissing || passwordMissing) {
      setState(() {
        _usernameError = usernameMissing ? 'Enter your username.' : null;
        _passwordError = passwordMissing ? 'Enter your password.' : null;
        _errorMessage = 'Enter your username and password.';
      });
      if (usernameMissing) {
        _usernameFocus.requestFocus();
      } else {
        _passwordFocus.requestFocus();
      }
      return;
    }

    // Preserve the teammate's exact case-sensitive, trimmed credential rules.
    // A failed Marketing attempt must never fall through to Inventory.
    if (username == 'marketing') {
      setState(() {
        _submitting = true;
        _errorMessage = '';
        _usernameError = null;
        _passwordError = null;
      });
      try {
        await marketingSession.login(rawUsername, password);
        if (!mounted) return;
        session.logout();
        _passwordController.clear();
        Navigator.pushReplacementNamed(context, '/marketing');
      } on MarketingAuthException catch (error) {
        if (mounted) setState(() => _errorMessage = error.toString());
      } catch (_) {
        if (mounted) {
          setState(
            () => _errorMessage = 'Marketing authentication is unavailable.',
          );
        }
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = '';
      _usernameError = null;
      _passwordError = null;
    });
    try {
      // Backend owns normalization. Never trim Inventory passwords.
      await session.login(rawUsername, password);
      if (!mounted) return;
      _passwordController.clear();
      Navigator.pushReplacementNamed(context, '/inventory');
    } on InventoryAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Inventory authentication is unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final split = constraints.maxWidth >= 900;
            final compact = constraints.maxWidth < 480;
            final form = _LoginFormCard(
              usernameController: _usernameController,
              passwordController: _passwordController,
              usernameFocus: _usernameFocus,
              passwordFocus: _passwordFocus,
              usernameError: _usernameError,
              passwordError: _passwordError,
              errorMessage: _errorMessage,
              sessionReady: _sessionReady,
              submitting: _submitting,
              hidePassword: _hidePassword,
              onUsernameChanged: (_) {
                if (_usernameError != null || _errorMessage.isNotEmpty) {
                  setState(() {
                    _usernameError = null;
                    _errorMessage = '';
                  });
                }
              },
              onPasswordChanged: (_) {
                if (_passwordError != null || _errorMessage.isNotEmpty) {
                  setState(() {
                    _passwordError = null;
                    _errorMessage = '';
                  });
                }
              },
              onTogglePassword: () =>
                  setState(() => _hidePassword = !_hidePassword),
              onSubmit: _login,
            );
            return Stack(
              children: [
                Positioned(
                  top: -140,
                  right: -100,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary.withValues(alpha: .07),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 18 : 36,
                    vertical: compact ? 20 : 36,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (compact ? 40 : 72),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: split
                            ? Row(
                                children: [
                                  const Expanded(child: _LoginBrandPanel()),
                                  const SizedBox(width: 56),
                                  SizedBox(width: 440, child: form),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const _CompactLoginBrand(),
                                  SizedBox(height: compact ? 20 : 28),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    child: form,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.usernameController,
    required this.passwordController,
    required this.usernameFocus,
    required this.passwordFocus,
    required this.usernameError,
    required this.passwordError,
    required this.errorMessage,
    required this.sessionReady,
    required this.submitting,
    required this.hidePassword,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final FocusNode usernameFocus;
  final FocusNode passwordFocus;
  final String? usernameError;
  final String? passwordError;
  final String errorMessage;
  final bool sessionReady;
  final bool submitting;
  final bool hidePassword;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 480 ? 24 : 36),
      decoration: BoxDecoration(
        color: ApplicationColors.panel(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ApplicationColors.border(context)),
        boxShadow: ApplicationElevation.forBrightness(theme.brightness),
      ),
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Welcome Back',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to access your Smart Omni-Retail workspace.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (errorMessage.isNotEmpty) ...[
              Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.error.withValues(alpha: .28),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, color: scheme.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Text('Username', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: usernameController,
              focusNode: usernameFocus,
              enabled: sessionReady && !submitting,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Enter your username',
                prefixIcon: const Icon(Icons.person_outline),
                errorText: usernameError,
              ),
              onChanged: onUsernameChanged,
              onSubmitted: (_) => passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 18),
            Text('Password', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              focusNode: passwordFocus,
              enabled: sessionReady && !submitting,
              obscureText: hidePassword,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline),
                errorText: passwordError,
                suffixIcon: IconButton(
                  tooltip: hidePassword ? 'Show password' : 'Hide password',
                  onPressed: submitting ? null : onTogglePassword,
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: onPasswordChanged,
              onSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 26),
            ElevatedButton(
              onPressed: sessionReady && !submitting ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: submitting
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            semanticsLabel: 'Signing in',
                          ),
                        ),
                        SizedBox(width: 10),
                        Text('Signing in…'),
                      ],
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Authentication is verified securely by your workspace.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _LoginBrandMark(),
          const SizedBox(height: 28),
          Text(
            'Smart Omni-Retail',
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Smarter Decisions. Personalized Experiences. Seamless Retail.',
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'An integrated retail intelligence platform connecting inventory '
            'optimization, personalized marketing, and intelligent shopping '
            'experiences.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          const _BrandFeature(
            icon: Icons.insights_outlined,
            title: 'Intelligent Operations',
            description:
                'Optimize stock, anticipate demand, and support smarter '
                'business decisions.',
          ),
          const SizedBox(height: 16),
          const _BrandFeature(
            icon: Icons.auto_awesome_outlined,
            title: 'Personalized Experiences',
            description:
                'Connect customer insights, targeted marketing, and '
                'interactive shopping experiences.',
          ),
        ],
      ),
    );
  }
}

class _CompactLoginBrand extends StatelessWidget {
  const _CompactLoginBrand();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _LoginBrandMark(),
      const SizedBox(height: 14),
      Text(
        'Smart Omni-Retail',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 5),
      Text(
        'Smarter Decisions. Personalized Experiences. Seamless Retail.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

class _LoginBrandMark extends StatelessWidget {
  const _LoginBrandMark();

  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .22),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Icon(
      Icons.hub_outlined,
      color: Theme.of(context).colorScheme.onPrimary,
      size: 30,
    ),
  );
}

class _BrandFeature extends StatelessWidget {
  const _BrandFeature({
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 14),
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
            const SizedBox(height: 3),
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

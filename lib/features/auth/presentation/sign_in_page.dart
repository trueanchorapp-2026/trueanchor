import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/auth_providers.dart';
import 'auth_form_fields.dart';
import 'google_sign_in_button.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    // On success the router's redirect ladder takes over; no manual navigation.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final busy = authState.isLoading;

    return Scaffold(
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            Icon(Icons.anchor, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: AppTheme.space3),
            Text(
              'TrueAnchor',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              'Sign in to continue',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space6),
            EmailField(controller: _email, enabled: !busy),
            const SizedBox(height: AppTheme.space4),
            PasswordField(
              controller: _password,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: busy ? null : (_) => _submit(),
            ),
            if (authState.hasError) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: '${authState.error}'),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const ButtonSpinner()
                  : const Text('Sign in'),
            ),
            const SizedBox(height: AppTheme.space4),
            const AuthDivider(),
            const SizedBox(height: AppTheme.space4),
            GoogleSignInButton(enabled: !busy),
            const SizedBox(height: AppTheme.space3),
            TextButton(
              onPressed: busy ? null : () => context.go(Routes.signUp),
              child: const Text("New here? Create an account"),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';
import 'auth_form_fields.dart';
import 'google_sign_in_button.dart';
import 'invite_code_field.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();

  InvitePreview? _preview;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preview == null) return;

    await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
          inviteCode: _inviteCode.text,
        );
    // The router redirects on success.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final busy = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create your account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: busy ? null : () => context.go(Routes.signIn),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            Text(
              'Your church code decides which church you join and what you '
              'can see. Ask your church for one if you do not have it.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space5),
            InviteCodeField(
              controller: _inviteCode,
              enabled: !busy,
              onPreviewChanged: (preview) => setState(() => _preview = preview),
            ),
            const SizedBox(height: AppTheme.space5),
            Row(
              children: [
                Expanded(
                  child: RequiredTextField(
                    controller: _firstName,
                    label: 'First name',
                    enabled: !busy,
                    emptyMessage: 'Enter your first name.',
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: RequiredTextField(
                    controller: _lastName,
                    label: 'Last name',
                    enabled: !busy,
                    emptyMessage: 'Enter your last name.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            EmailField(controller: _email, enabled: !busy),
            const SizedBox(height: AppTheme.space4),
            PasswordField(
              controller: _password,
              enabled: !busy,
              validateStrength: true,
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
                  : const Text('Create account'),
            ),
            const SizedBox(height: AppTheme.space4),
            const AuthDivider(),
            const SizedBox(height: AppTheme.space4),
            GoogleSignInButton(enabled: !busy),
            const SizedBox(height: AppTheme.space3),
            TextButton(
              onPressed: busy ? null : () => context.go(Routes.signIn),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    );
  }
}

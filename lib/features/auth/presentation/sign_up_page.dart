import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';
import 'auth_form_fields.dart';

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

  /// The code we have actually asked the server about. Kept separate from the
  /// controller text so we look it up once the user pauses, not per keystroke.
  String _checkedCode = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    _debounce?.cancel();
    final normalised = value.trim().toUpperCase();
    if (normalised == _checkedCode) return;

    // Clear a stale confirmation immediately so it can't be mistaken for a
    // result for the code now in the box.
    if (_checkedCode.isNotEmpty) setState(() => _checkedCode = '');

    if (normalised.length < 4) return;
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _checkedCode = normalised);
    });
  }

  Future<void> _submit(InvitePreview? preview) async {
    if (!_formKey.currentState!.validate()) return;
    if (preview == null) return;

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

    final previewState = _checkedCode.isEmpty
        ? const AsyncData<InvitePreview?>(null)
        : ref.watch(invitePreviewProvider(_checkedCode));
    final preview = previewState.value;

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
            TextFormField(
              controller: _inviteCode,
              enabled: !busy,
              onChanged: _onCodeChanged,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseFormatter()],
              decoration: InputDecoration(
                labelText: 'Church code',
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                suffixIcon: previewState.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(AppTheme.space3),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : preview != null
                        ? Icon(Icons.check_circle,
                            color: theme.colorScheme.primary)
                        : null,
              ),
              validator: (value) {
                if ((value?.trim().isEmpty ?? true)) {
                  return 'Enter the code your church gave you.';
                }
                if (preview == null) {
                  return 'That code is not valid. Check it with your church.';
                }
                return null;
              },
            ),
            if (preview != null) ...[
              const SizedBox(height: AppTheme.space3),
              _InviteConfirmation(preview: preview),
            ],
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
              onPressed: busy ? null : () => _submit(preview),
              child: busy
                  ? const ButtonSpinner()
                  : const Text('Create account'),
            ),
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

/// Confirms the church and role a code resolves to, before the user commits.
class _InviteConfirmation extends StatelessWidget {
  const _InviteConfirmation({required this.preview});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.church_outlined,
              size: 20, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: AppTheme.space2),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                children: [
                  const TextSpan(text: 'Joining '),
                  TextSpan(
                    text: preview.churchName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' as '),
                  TextSpan(
                    text: preview.role.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invite codes are stored upper-case; normalising as the user types keeps the
/// field, the lookup and the submitted value all in agreement.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

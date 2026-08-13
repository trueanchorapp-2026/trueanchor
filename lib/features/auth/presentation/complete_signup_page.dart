import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/auth_providers.dart';
import '../../profile/domain/user_role.dart';
import '../domain/auth_repository.dart';
import 'auth_form_fields.dart';
import 'invite_code_field.dart';

/// Where a Google user lands the first time: they have a session but no profile
/// yet, because OAuth carried no invite code into the signup trigger. Entering
/// a church code here calls `claim_invite`, which creates their profile; the
/// router then routes them onward (family setup, or their home).
class CompleteSignUpPage extends ConsumerStatefulWidget {
  const CompleteSignUpPage({super.key});

  @override
  ConsumerState<CompleteSignUpPage> createState() =>
      _CompleteSignUpPageState();
}

class _CompleteSignUpPageState extends ConsumerState<CompleteSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _inviteCode = TextEditingController();

  InvitePreview? _preview;

  @override
  void initState() {
    super.initState();
    // Prefill names from the Google account when it provided them.
    final metadata =
        ref.read(currentSessionProvider)?.user.userMetadata ?? const {};
    final full = (metadata['full_name'] ?? metadata['name'])?.toString().trim();
    final given = metadata['given_name']?.toString().trim();
    final family = metadata['family_name']?.toString().trim();
    if (given != null && given.isNotEmpty) _firstName.text = given;
    if (family != null && family.isNotEmpty) _lastName.text = family;
    if ((given == null || given.isEmpty) && full != null && full.isNotEmpty) {
      final parts = full.split(RegExp(r'\s+'));
      _firstName.text = parts.first;
      if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_preview == null) return;

    final bool ok;
    if (_preview!.role == UserRole.regionalAdmin) {
      ok = await ref
          .read(authControllerProvider.notifier)
          .claimRegionalInvite(
            firstName: _firstName.text,
            lastName: _lastName.text,
            code: _inviteCode.text,
          );
    } else {
      ok = await ref.read(authControllerProvider.notifier).claimInvite(
            firstName: _firstName.text,
            lastName: _lastName.text,
            code: _inviteCode.text,
          );
    }
    if (!ok) return;

    // The profile now exists; re-read it so the router's redirect ladder can
    // route this user onward.
    await ref.read(currentProfileProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final busy = authState.isLoading;
    final email = ref.watch(currentSessionProvider)?.user.email;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finish setting up'),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            Text(
              email == null
                  ? "You're signed in. Enter your invite code to finish."
                  : "You're signed in as $email. Enter your invite code to "
                      'finish setting up your account.',
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
            if (authState.hasError) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: '${authState.error}'),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy ? const ButtonSpinner() : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

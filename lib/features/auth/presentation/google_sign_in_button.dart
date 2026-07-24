import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/auth_providers.dart';

/// "Continue with Google" for the sign-in and sign-up screens.
///
/// On web this hands off to Supabase's OAuth redirect, so there is no success
/// path to handle here — the page navigates away. A new Google user comes back
/// with a session but no profile and the router sends them to complete signup;
/// a returning one lands straight in the app.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({this.enabled = true, super.key});

  final bool enabled;

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).signInWithGoogle();
    } catch (error) {
      if (context.mounted) showAppSnack(context, '$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => _signIn(context, ref) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      icon: const Icon(Icons.login),
      label: const Text('Continue with Google'),
    );
  }
}

/// A centred "or" between the primary form and the OAuth option.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
          child: Text(
            'or',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

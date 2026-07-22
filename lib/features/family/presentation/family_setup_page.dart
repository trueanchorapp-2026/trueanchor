import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../auth/presentation/sign_up_page.dart' show UpperCaseFormatter;
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/family_providers.dart';

enum _SetupMode { create, join }

/// Gate between signing up and using the app, for the roles that belong to a
/// household.
///
/// Anyone joining an existing household does so with its code — a second
/// parent, a grandparent and a youth all take the same path. Only creating one
/// is restricted, because the creator becomes head of household.
class FamilySetupPage extends ConsumerStatefulWidget {
  const FamilySetupPage({super.key});

  @override
  ConsumerState<FamilySetupPage> createState() => _FamilySetupPageState();
}

class _FamilySetupPageState extends ConsumerState<FamilySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _input = TextEditingController();

  /// Null until we know the role: youth never get the choice, so their mode is
  /// derived rather than picked.
  _SetupMode? _mode;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _selectMode(_SetupMode mode) {
    if (mode == _mode) return;
    // The field means something different in each mode, so a half-typed family
    // name must not survive into the code box. Reset first: it restores the
    // controller to the text it held at the last build, so clearing before it
    // would just be undone.
    _formKey.currentState?.reset();
    _input.clear();
    setState(() => _mode = mode);
  }

  Future<void> _submit(_SetupMode mode) async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(familyControllerProvider.notifier);
    if (mode == _SetupMode.create) {
      await controller.create(_input.text);
    } else {
      await controller.join(_input.text);
    }
    // On success the refreshed profile releases the router's gate.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final state = ref.watch(familyControllerProvider);
    final busy = state.isLoading;

    // Youth join the household a parent already set up; create_family refuses
    // them server-side anyway, so offering the choice would only mislead.
    final canCreate = profile?.role != UserRole.youth;
    final mode = canCreate ? (_mode ?? _SetupMode.create) : _SetupMode.join;
    final isCreating = mode == _SetupMode.create;

    return Scaffold(
      appBar: AppBar(
        title: const Text('One more step'),
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
            Icon(
              isCreating ? Icons.home_outlined : Icons.group_add_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              isCreating ? 'Set up your family' : 'Join your family',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              _blurbFor(mode, canCreate: canCreate),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (canCreate) ...[
              const SizedBox(height: AppTheme.space5),
              SegmentedButton<_SetupMode>(
                segments: const [
                  ButtonSegment(
                    value: _SetupMode.create,
                    label: Text('Create'),
                    icon: Icon(Icons.add_home_outlined),
                  ),
                  ButtonSegment(
                    value: _SetupMode.join,
                    label: Text('Join'),
                    icon: Icon(Icons.group_add_outlined),
                  ),
                ],
                selected: {mode},
                onSelectionChanged:
                    busy ? null : (values) => _selectMode(values.first),
              ),
            ],
            const SizedBox(height: AppTheme.space5),
            TextFormField(
              controller: _input,
              enabled: !busy,
              textCapitalization: isCreating
                  ? TextCapitalization.words
                  : TextCapitalization.characters,
              inputFormatters: isCreating ? null : [UpperCaseFormatter()],
              decoration: InputDecoration(
                labelText: isCreating ? 'Family name' : 'Family code',
                hintText: isCreating ? 'The Nguyen Family' : 'A1B2C3',
                prefixIcon: Icon(
                  isCreating ? Icons.badge_outlined : Icons.vpn_key_outlined,
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return isCreating
                      ? 'Give your family a name.'
                      : 'Enter your family code.';
                }
                if (!isCreating && text.length < 6) {
                  return 'Family codes are 6 characters.';
                }
                return null;
              },
            ),
            if (state.hasError) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: '${state.error}'),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: busy ? null : () => _submit(mode),
              child: busy
                  ? const ButtonSpinner()
                  : Text(isCreating ? 'Create family' : 'Join family'),
            ),
          ],
        ),
      ),
    );
  }
}

String _blurbFor(_SetupMode mode, {required bool canCreate}) {
  if (mode == _SetupMode.create) {
    return 'Name your household. You become its head of household, and you '
        'will get a code to share so the rest of your family can join.';
  }
  return canCreate
      ? 'Enter the code from whoever set up your household. They can give you '
          'a role once you are in.'
      : 'Enter the family code from your parent. It connects your account to '
          'your household.';
}

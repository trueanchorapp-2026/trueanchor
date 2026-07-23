import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../auth/presentation/sign_up_page.dart' show UpperCaseFormatter;
import '../../profile/domain/user_role.dart';
import '../application/church_providers.dart';
import '../domain/church.dart';

/// Opens the "new invite code" form. Church admins only — the caller decides
/// whether to offer it, and the `invites_insert` policy is the real gate.
Future<void> showIssueInviteSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: const IssueInviteSheet(),
    ),
  );
}

class IssueInviteSheet extends ConsumerStatefulWidget {
  const IssueInviteSheet({super.key});

  @override
  ConsumerState<IssueInviteSheet> createState() => _IssueInviteSheetState();
}

class _IssueInviteSheetState extends ConsumerState<IssueInviteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController(text: ChurchInvite.generateCode());
  final _maxUses = TextEditingController(text: '25');

  UserRole _role = UserRole.parent;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final ok = await ref.read(inviteControllerProvider.notifier).issue(
          code: _code.text,
          role: _role,
          maxUses: int.parse(_maxUses.text.trim()),
        );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      showAppSnack(context, 'Code ${ChurchInvite.normalizeCode(_code.text)} '
          'created.');
      return;
    }

    setState(() {
      _error = '${ref.read(inviteControllerProvider).error}';
      _saving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space5,
            0,
            AppTheme.space5,
            AppTheme.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New invite code', style: theme.textTheme.titleLarge),
              const SizedBox(height: AppTheme.space2),
              Text(
                'Anyone with this code can join your church in the role you '
                'pick. Share it only with people you mean to.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space5),
              TextFormField(
                controller: _code,
                enabled: !_saving,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [UpperCaseFormatter()],
                decoration: InputDecoration(
                  labelText: 'Code',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Generate another',
                    icon: const Icon(Icons.casino_outlined),
                    onPressed: _saving
                        ? null
                        : () => setState(
                              () => _code.text = ChurchInvite.generateCode(),
                            ),
                  ),
                ),
                validator: (value) {
                  final code = ChurchInvite.normalizeCode(value ?? '');
                  if (code.isEmpty) return 'Enter a code, or generate one.';
                  if (code.length < 4) {
                    return 'Use at least 4 characters so it is hard to guess.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.space4),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: [
                  for (final role in issuableInviteRoles)
                    DropdownMenuItem(value: role, child: Text(role.label)),
                ],
                onChanged: _saving
                    ? null
                    : (role) => setState(() => _role = role ?? _role),
              ),
              const SizedBox(height: AppTheme.space4),
              TextFormField(
                controller: _maxUses,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'How many people can use it',
                  prefixIcon: Icon(Icons.groups_outlined),
                  helperText: 'The code stops working once it runs out.',
                ),
                validator: (value) {
                  final uses = int.tryParse(value?.trim() ?? '');
                  if (uses == null || uses < 1) {
                    return 'Enter a number of 1 or more.';
                  }
                  if (uses > 1000) return 'Keep it to 1000 or fewer.';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: AppTheme.space4),
                FormErrorBanner(message: _error!),
              ],
              const SizedBox(height: AppTheme.space5),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child:
                    _saving ? const ButtonSpinner() : const Text('Create code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

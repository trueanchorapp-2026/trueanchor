import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../milestones/application/milestone_providers.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';
import '../domain/user_role.dart';

/// Edits the signed-in user's own profile, or — when [memberId] is set — a
/// youth in their household, who may be too young to keep it up themselves.
///
/// Which of those it is only changes where the row comes from and where it is
/// written back. The permission question is settled by RLS
/// (`profiles_update_family_youth`), not here.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({this.memberId, super.key});

  final String? memberId;

  bool get isEditingSelf => memberId == null;

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _grade = TextEditingController();
  final _gender = TextEditingController();

  DateTime? _birthDate;
  DateTime? _baptizedOn;
  bool _baptized = false;

  bool _initialised = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _grade.dispose();
    _gender.dispose();
    super.dispose();
  }

  /// Seeds the controllers once, the first time the profile is available.
  void _hydrate(Profile profile) {
    if (_initialised) return;
    _initialised = true;
    _firstName.text = profile.firstName;
    _lastName.text = profile.lastName;
    _phone.text = profile.phone ?? '';
    _grade.text = profile.grade?.toString() ?? '';
    _gender.text = profile.gender ?? '';
    _birthDate = profile.birthDate;
    _baptizedOn = profile.baptizedOn;
    _baptized = profile.baptized;
  }

  Future<void> _save(Profile original) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final gradeText = _grade.text.trim();
    final updated = original.copyWith(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      phone: _phone.text.trim(),
      gender: _gender.text.trim(),
      grade: gradeText.isEmpty ? null : int.tryParse(gradeText),
      clearGrade: gradeText.isEmpty,
      birthDate: _birthDate,
      clearBirthDate: _birthDate == null,
      baptized: _baptized,
      baptizedOn: _baptized ? _baptizedOn : null,
      clearBaptizedOn: !_baptized || _baptizedOn == null,
    );

    try {
      if (widget.isEditingSelf) {
        await ref.read(currentProfileProvider.notifier).save(updated);
      } else {
        await ref.read(householdMemberEditorProvider.notifier).save(updated);
      }
      // Saving baptism makes the database log a matching milestone (see
      // `sync_baptism_milestone`), so a cached list is now behind the server.
      if (original.baptized != updated.baptized ||
          original.baptizedOn != updated.baptizedOn) {
        ref.invalidate(milestoneListProvider);
      }
      if (mounted) {
        showAppSnack(context, 'Profile saved.');
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = '$error';
          _saving = false;
        });
      }
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 14, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  /// The row being edited: the caller's own, or the household member named in
  /// the route. A member id that matches nobody in the household resolves to
  /// null and is reported as not found.
  AsyncValue<Profile?> _target() {
    final memberId = widget.memberId;
    if (memberId == null) return ref.watch(currentProfileProvider);

    return ref.watch(familyMembersProvider).whenData((members) {
      for (final member in members) {
        if (member.id == memberId) return member;
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = _target();
    final name = profileState.value?.firstName;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch ((widget.isEditingSelf, name)) {
            (true, _) => 'Edit profile',
            (false, final String n) when n.isNotEmpty => "$n's details",
            (false, _) => 'Edit details',
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: AsyncValueView(
        value: profileState,
        builder: (profile) {
          if (profile == null) {
            return EmptyState(
              icon: Icons.person_off_outlined,
              title: widget.isEditingSelf
                  ? 'No profile to edit'
                  : 'Member not found',
              message: widget.isEditingSelf
                  ? null
                  : 'They may have left your household.',
            );
          }
          _hydrate(profile);
          final isYouth = profile.role == UserRole.youth;

          return Form(
            key: _formKey,
            child: ContentColumn(
              children: [
                RequiredTextField(
                  controller: _firstName,
                  label: 'First name',
                  enabled: !_saving,
                  emptyMessage: 'Enter a first name.',
                ),
                const SizedBox(height: AppTheme.space4),
                RequiredTextField(
                  controller: _lastName,
                  label: 'Last name',
                  enabled: !_saving,
                  emptyMessage: 'Enter a last name.',
                ),
                const SizedBox(height: AppTheme.space4),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (isYouth) ...[
                  const SizedBox(height: AppTheme.space5),
                  Text(
                    'Youth details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.space3),
                  _DateField(
                    label: 'Birth date',
                    value: _birthDate,
                    enabled: !_saving,
                    helper: 'Used to show age. The age itself is never stored.',
                    onTap: () => _pickDate(
                      initial: _birthDate,
                      onPicked: (date) => setState(() => _birthDate = date),
                    ),
                    onClear: () => setState(() => _birthDate = null),
                  ),
                  const SizedBox(height: AppTheme.space4),
                  TextFormField(
                    controller: _grade,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Grade (optional)',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final grade = int.tryParse(text);
                      if (grade == null || grade < 0 || grade > 12) {
                        return 'Enter a grade between 0 and 12.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppTheme.space4),
                  TextFormField(
                    controller: _gender,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space3),
                  SwitchListTile(
                    value: _baptized,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _baptized = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Baptized'),
                  ),
                  if (_baptized) ...[
                    const SizedBox(height: AppTheme.space2),
                    _DateField(
                      label: 'Baptism date (optional)',
                      value: _baptizedOn,
                      enabled: !_saving,
                      onTap: () => _pickDate(
                        initial: _baptizedOn,
                        onPicked: (date) => setState(() => _baptizedOn = date),
                      ),
                      onClear: () => setState(() => _baptizedOn = null),
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppTheme.space4),
                  FormErrorBanner(message: _error!),
                ],
                const SizedBox(height: AppTheme.space5),
                FilledButton(
                  onPressed: _saving ? null : () => _save(profile),
                  child: _saving
                      ? const ButtonSpinner()
                      : const Text('Save changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.helper,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String? helper;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Text(
          value == null ? 'Not set' : DateFormat.yMMMd().format(value!),
        ),
      ),
    );
  }
}

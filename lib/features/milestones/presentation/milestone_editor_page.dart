import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../profile/domain/profile.dart';
import '../application/milestone_providers.dart';
import '../domain/milestone.dart';

class MilestoneEditorPage extends ConsumerStatefulWidget {
  const MilestoneEditorPage({super.key});

  @override
  ConsumerState<MilestoneEditorPage> createState() =>
      _MilestoneEditorPageState();
}

class _MilestoneEditorPageState extends ConsumerState<MilestoneEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _note = TextEditingController();

  String? _subjectId;
  MilestoneType _type = MilestoneType.acceptedChrist;
  DateTime _achievedOn = DateTime.now();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _achievedOn,
      firstDate: DateTime(now.year - 30),
      lastDate: now,
    );
    if (picked != null) setState(() => _achievedOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final subjectId = _subjectId;
    if (subjectId == null) {
      setState(() => _error = 'Choose who this milestone is for.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(milestoneListProvider.notifier).add(
            profileId: subjectId,
            milestoneType: _type,
            title: _title.text,
            note: _note.text,
            achievedOn: _achievedOn,
          );
      if (mounted) {
        showAppSnack(context, 'Milestone recorded.');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectsState = ref.watch(milestoneSubjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record a milestone'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            AsyncValueView(
              value: subjectsState,
              builder: (subjects) {
                if (subjects.isEmpty) {
                  return const FormErrorBanner(
                    message: 'There are no youth you can record a milestone '
                        'for yet. Add a youth to your family first.',
                  );
                }
                return _SubjectDropdown(
                  subjects: subjects,
                  value: _subjectId,
                  enabled: !_saving,
                  onChanged: (id) => setState(() => _subjectId = id),
                );
              },
            ),
            const SizedBox(height: AppTheme.space4),
            DropdownButtonFormField<MilestoneType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Milestone',
                prefixIcon: Icon(Icons.emoji_events_outlined),
              ),
              items: [
                for (final type in MilestoneType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 18),
                        const SizedBox(width: AppTheme.space2),
                        Text(type.label),
                      ],
                    ),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _type = value);
                    },
            ),
            const SizedBox(height: AppTheme.space4),
            InkWell(
              onTap: _saving ? null : _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date achieved',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                child: Text(DateFormat.yMMMd().format(_achievedOn)),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
                helperText: 'Defaults to the milestone name if left blank.',
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _note,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const ButtonSpinner()
                  : const Text('Save milestone'),
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              'Youth can see their own milestones. Parents see their family; '
              'youth pastors and church admins see the church.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectDropdown extends StatelessWidget {
  const _SubjectDropdown({
    required this.subjects,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<Profile> subjects;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'For whom',
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: [
        for (final subject in subjects)
          DropdownMenuItem(value: subject.id, child: Text(subject.fullName)),
      ],
      onChanged: enabled ? onChanged : null,
      validator: (value) => value == null ? 'Choose who this is for.' : null,
    );
  }
}

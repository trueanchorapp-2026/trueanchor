import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/journal_providers.dart';
import '../domain/journal_entry.dart';

class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({super.key});

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  EntryType _type = EntryType.journal;

  /// Private by default. Sharing must be a deliberate act, never a default the
  /// user has to notice and undo.
  EntryVisibility _visibility = EntryVisibility.private;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(journalListProvider.notifier).add(
            title: _title.text,
            body: _body.text,
            entryType: _type,
            visibility: _visibility,
          );
      if (mounted) {
        showAppSnack(context, 'Entry saved.');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('New entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(
                  value: EntryType.journal,
                  icon: Icon(Icons.edit_note_outlined),
                  label: Text('Journal'),
                ),
                ButtonSegment(
                  value: EntryType.prayer,
                  icon: Icon(Icons.volunteer_activism_outlined),
                  label: Text('Prayer'),
                ),
              ],
              selected: {_type},
              onSelectionChanged: _saving
                  ? null
                  : (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: AppTheme.space5),
            TextFormField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title (optional)',
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _body,
              enabled: !_saving,
              minLines: 6,
              maxLines: 14,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _type == EntryType.prayer
                    ? 'What are you praying for?'
                    : 'What is on your heart?',
                alignLabelWithHint: true,
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Write something before saving.'
                  : null,
            ),
            const SizedBox(height: AppTheme.space5),
            Text('Who can see this?', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space2),
            // RadioGroup.onChanged is non-nullable, so the in-flight lockout
            // is done by ignoring pointers rather than by nulling the handler.
            IgnorePointer(
              ignoring: _saving,
              child: RadioGroup<EntryVisibility>(
                groupValue: _visibility,
                onChanged: (value) {
                  if (value != null) setState(() => _visibility = value);
                },
                child: Column(
                  children: [
                    for (final option in EntryVisibility.values)
                      RadioListTile<EntryVisibility>(
                        value: option,
                        contentPadding: EdgeInsets.zero,
                        title: Text(option.label),
                        subtitle: Text(
                          option.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving ? const ButtonSpinner() : const Text('Save entry'),
            ),
          ],
        ),
      ),
    );
  }
}

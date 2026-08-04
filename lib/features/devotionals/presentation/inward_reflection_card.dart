import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../journal/application/journal_providers.dart';
import '../../journal/domain/journal_entry.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';

/// Inline journal / prayer input for the Inward Reflection section of a
/// devotional. Shows the user's saved reflection if one exists, or a text
/// field to write one.
class InwardReflectionCard extends ConsumerStatefulWidget {
  const InwardReflectionCard({required this.devotionalId, super.key});

  final String devotionalId;

  @override
  ConsumerState<InwardReflectionCard> createState() =>
      _InwardReflectionCardState();
}

class _InwardReflectionCardState extends ConsumerState<InwardReflectionCard> {
  final _body = TextEditingController();
  EntryType _type = EntryType.journal;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;

    final profile = ref.read(currentProfileProvider).value;
    final role = profile?.role ?? UserRole.youth;
    final visibility = EntryVisibility.defaultFor(role);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(journalListProvider.notifier);
      final existing = ref.read(
        devotionalReflectionProvider(widget.devotionalId),
      );

      if (existing.value != null) {
        await notifier.edit(
          entryId: existing.value!.id,
          title: null,
          body: text,
          entryType: _type,
          visibility: visibility,
        );
      } else {
        await notifier.add(
          title: null,
          body: text,
          entryType: _type,
          visibility: visibility,
          devotionalId: widget.devotionalId,
        );
      }

      ref.invalidate(devotionalReflectionProvider(widget.devotionalId));

      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        showAppSnack(context, 'Reflection saved.');
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reflection = ref.watch(
      devotionalReflectionProvider(widget.devotionalId),
    );
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null || !profile.role.tracksDailyProgress) {
      return const SizedBox.shrink();
    }

    return reflection.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.space4),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (entry) {
        if (entry != null && !_editing) return _SavedReflection(entry: entry, onEdit: _startEditing);
        return _buildEditor(entry);
      },
    );
  }

  void _startEditing() {
    final entry = ref.read(
      devotionalReflectionProvider(widget.devotionalId),
    ).value;
    if (entry != null) {
      _body.text = entry.body;
      _type = entry.entryType;
    }
    setState(() => _editing = true);
  }

  Widget _buildEditor(JournalEntry? existing) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _body,
              enabled: !_saving,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: _type == EntryType.prayer
                    ? 'What are you praying for?'
                    : 'Write your reflection...',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppTheme.space3),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.space4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editing)
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = false),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: AppTheme.space2),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const ButtonSpinner()
                      : Text(existing != null ? 'Update' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedReflection extends StatelessWidget {
  const _SavedReflection({required this.entry, required this.onEdit});

  final JournalEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.entryType == EntryType.prayer
                      ? Icons.volunteer_activism_outlined
                      : Icons.edit_note_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    entry.entryType == EntryType.prayer
                        ? 'Your prayer'
                        : 'Your reflection',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(entry.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

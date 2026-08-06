import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/journal_providers.dart';
import '../domain/journal_entry.dart';

/// Writes a new entry, or rewrites one the signed-in user already owns.
///
/// [entryId] is resolved against the loaded list rather than passed as a route
/// `extra`, so a bookmarked or refreshed `/journal/:id/edit` URL still works on
/// web, where `extra` does not survive a reload.
class JournalEditorPage extends ConsumerStatefulWidget {
  const JournalEditorPage({
    this.entryId,
    this.devotionalId,
    this.initialType,
    super.key,
  });

  final String? entryId;
  final String? devotionalId;
  final EntryType? initialType;

  bool get isEditing => entryId != null;

  @override
  ConsumerState<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends ConsumerState<JournalEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();

  late EntryType _type;

  /// Null until the author ticks a box, or until an edited entry is hydrated.
  /// The fallback is [EntrySharing.none], which resolves against the author's
  /// role — a youth's floor is `private`, a parent's is their household's
  /// other adults — and so cannot be read until the profile loads.
  EntrySharing? _sharing;

  /// The visibility an edited entry arrived with, kept only to notice a
  /// legacy parent-authored `private` entry that the checkboxes cannot
  /// express. See [EntryVisibility.isLegacyPrivateFor].
  EntryVisibility? _originalVisibility;

  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? EntryType.journal;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Seeds the form once, the first time the entry being edited is available.
  void _hydrate(JournalEntry entry) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = entry.title ?? '';
    _body.text = entry.body;
    _type = entry.entryType;
    // Left as a visibility rather than decomposed here: splitting it into
    // checkboxes needs the author's role, which may still be loading. build
    // does it once the role is known.
    _originalVisibility = entry.visibility;
  }

  /// Stores a tick, normalised so the boxes can only ever show a combination
  /// the database can store. See [EntrySharing.normalizedFor] — this is what
  /// makes a youth's pastor tick pull the family box on with it.
  void _setSharing(EntrySharing sharing, UserRole role) {
    setState(() => _sharing = sharing.normalizedFor(role));
  }

  Future<void> _save(EntryVisibility visibility) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(journalListProvider.notifier);
      final entryId = widget.entryId;
      if (entryId == null) {
        await notifier.add(
          title: _title.text,
          body: _body.text,
          entryType: _type,
          visibility: visibility,
          devotionalId: widget.devotionalId,
        );
      } else {
        await notifier.edit(
          entryId: entryId,
          title: _title.text,
          body: _body.text,
          entryType: _type,
          visibility: visibility,
        );
      }
      if (mounted) {
        showAppSnack(context, widget.isEditing ? 'Entry updated.' : 'Entry saved.');
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit entry' : 'New entry'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: widget.isEditing ? _buildForEdit() : _buildForm(),
    );
  }

  Widget _buildForEdit() {
    final entriesState = ref.watch(journalListProvider);

    return AsyncValueView(
      value: entriesState,
      onRetry: () => ref.read(journalListProvider.notifier).refresh(),
      builder: (entries) {
        JournalEntry? entry;
        for (final candidate in entries) {
          if (candidate.id == widget.entryId) entry = candidate;
        }

        // Either the entry was deleted from another device, or RLS never
        // returned it. Both mean the same thing to the user.
        if (entry == null) {
          return const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'Entry not found',
            message: 'It may have been deleted.',
          );
        }

        _hydrate(entry);
        return _buildForm();
      },
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;

    // Youth is the safer assumption while the profile loads: its ladder starts
    // at `private`, so a slow load can never widen an entry by default.
    final role = profile?.role ?? UserRole.youth;

    // Decomposed here rather than at hydrate time because the split depends
    // on the role: `parents` is an act of sharing for a youth and the floor
    // for a parent.
    final sharing = _sharing ??
        EntrySharing.from(
          _originalVisibility ?? EntryVisibility.defaultFor(role),
          role,
        );
    final visibility = sharing.resolve(role);

    // A parent-authored `private` entry predates the rule that parents share
    // a floor with the other adults in their household. The checkboxes cannot
    // express it, so saving widens it — which the author is told, not shown
    // after the fact.
    final wideningLegacyPrivate =
        _originalVisibility?.isLegacyPrivateFor(role) ?? false;

    // Every sharing policy matches on family_id, so an author with no
    // household would be sharing with nobody at all.
    final hasFamily = profile?.hasFamily ?? true;
    final sharesWithNobody = visibility.needsFamily && !hasFamily;

    // A "+ pastor" rung with no youth pastor in the church reaches exactly as
    // far as the rung below it. Say so rather than imply someone is listening.
    final hasPastor = ref.watch(churchHasYouthPastorProvider).value ?? true;
    final pastorIsMissing = visibility.needsYouthPastor && !hasPastor;

    return Form(
      key: _formKey,
      child: ContentColumn(
        children: [
          if (widget.devotionalId == null && widget.initialType == null) ...[
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
          ],
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
          Text('Share this with', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppTheme.space1),
          Text(
            EntrySharing.floorHintFor(role),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space2),
          _SharingCheckbox(
            enabled: !_saving,
            value: sharing.withFamily,
            title: EntrySharing.familyLabelFor(role),
            subtitle: EntrySharing.familyHintFor(role),
            onChanged: (checked) => _setSharing(
              sharing.copyWith(withFamily: checked),
              role,
            ),
          ),
          _SharingCheckbox(
            enabled: !_saving,
            value: sharing.withPastor,
            title: EntrySharing.pastorLabelFor(role),
            // A youth ticking this also ticks the box above, because
            // `entry_visibility` has no "pastor but not my parents" value and
            // the product does not want one. Saying so beats a box that
            // silently moves on its own.
            subtitle: role == UserRole.youth
                ? 'Your youth pastor reads these alongside the adults in '
                    'your family, never instead of them.'
                : 'Your church\'s youth pastor can read this. No other church '
                    'staff can.',
            onChanged: (checked) => _setSharing(
              sharing.copyWith(withPastor: checked),
              role,
            ),
          ),
          if (wideningLegacyPrivate) ...[
            const SizedBox(height: AppTheme.space3),
            const NoticeBanner(
              icon: Icons.info_outline,
              message: 'This entry was private. Saving it will make it '
                  'readable by the other adults in your household, which is '
                  'where parents\' entries now start.',
            ),
          ],
          if (sharesWithNobody) ...[
            const SizedBox(height: AppTheme.space3),
            const NoticeBanner(
              icon: Icons.info_outline,
              message: "You are not in a family yet, so nobody can see this "
                  'entry. Set up your family first if you meant to share it.',
            ),
          ],
          if (pastorIsMissing) ...[
            const SizedBox(height: AppTheme.space3),
            const NoticeBanner(
              icon: Icons.info_outline,
              message: 'Your church has not added a youth pastor yet, so for '
                  'now this reaches only your family. It will become visible '
                  'to a youth pastor once your church has one.',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppTheme.space4),
            FormErrorBanner(message: _error!),
          ],
          const SizedBox(height: AppTheme.space5),
          FilledButton(
            onPressed: _saving ? null : () => _save(visibility),
            child: _saving
                ? const ButtonSpinner()
                : Text(widget.isEditing ? 'Save changes' : 'Save entry'),
          ),
        ],
      ),
    );
  }
}

/// One sharing tick, with the explanation of who it reaches sitting under it
/// rather than behind a tooltip — this is the one control in the app where
/// guessing wrong exposes something the author meant to keep close.
class _SharingCheckbox extends StatelessWidget {
  const _SharingCheckbox({
    required this.enabled,
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

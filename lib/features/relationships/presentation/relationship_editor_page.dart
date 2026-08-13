import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/domain/entry_visibility.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../journal/application/journal_providers.dart'
    show churchHasYouthPastorProvider;
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/relationship_providers.dart';
import '../domain/relationship.dart';

class RelationshipEditorPage extends ConsumerStatefulWidget {
  const RelationshipEditorPage({this.relationshipId, super.key});

  final String? relationshipId;

  bool get isEditing => relationshipId != null;

  @override
  ConsumerState<RelationshipEditorPage> createState() =>
      _RelationshipEditorPageState();
}

class _RelationshipEditorPageState
    extends ConsumerState<RelationshipEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _context = TextEditingController();
  final _nextStep = TextEditingController();

  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  /// What was stored, before the checkboxes touched it. Null on a new entry.
  EntryVisibility? _originalVisibility;

  /// Null until the author touches a box; see [_sharingFor].
  EntrySharing? _sharing;

  @override
  void dispose() {
    _name.dispose();
    _context.dispose();
    _nextStep.dispose();
    super.dispose();
  }

  void _hydrate(Relationship relationship) {
    if (_hydrated) return;
    _hydrated = true;
    _name.text = relationship.name;
    _context.text = relationship.context ?? '';
    _nextStep.text = relationship.nextStep ?? '';
    _originalVisibility = relationship.visibility;
  }

  /// The checkbox state, decomposed here rather than at hydrate time because
  /// the split depends on the role.
  ///
  /// A *new* relationship starts fully shared. Love in Action is outward growth
  /// a youth is meant to be encouraged in, and 0022 shipped every entry visible
  /// to parents and pastor — so this is the promise those authors already have.
  /// Unticking is always available; nothing widens on its own.
  EntrySharing _sharingFor(UserRole role) =>
      _sharing ??
      EntrySharing.from(
        _originalVisibility ?? EntryVisibility.parentsPastor,
        role,
      );

  void _setSharing(EntrySharing next, UserRole role) {
    setState(() => _sharing = next.normalizedFor(role));
  }

  Future<void> _save(EntryVisibility visibility) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(relationshipListProvider.notifier);
      if (widget.isEditing) {
        await notifier.edit(
          id: widget.relationshipId!,
          name: _name.text,
          visibility: visibility,
          context: _context.text,
          nextStep: _nextStep.text,
        );
      } else {
        await notifier.add(
          name: _name.text,
          visibility: visibility,
          context: _context.text,
          nextStep: _nextStep.text,
        );
      }
      if (mounted) {
        showAppSnack(context, widget.isEditing ? 'Updated.' : 'Person added.');
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

    if (widget.isEditing) {
      final relationships = ref.watch(relationshipListProvider).value;
      final existing = relationships
          ?.where((r) => r.id == widget.relationshipId)
          .firstOrNull;
      if (existing != null) _hydrate(existing);
    }

    final profile = ref.watch(currentProfileProvider).value;

    // Youth is the safer assumption while the profile loads: only a youth can
    // author here anyway, and its ladder cannot reach the wider rungs.
    final role = profile?.role ?? UserRole.youth;
    final sharing = _sharingFor(role);
    final visibility = sharing.resolve(role);

    // Every sharing policy matches on family_id, so an author with no
    // household would be sharing with nobody at all.
    final hasFamily = profile?.hasFamily ?? true;
    final sharesWithNobody = visibility.needsFamily && !hasFamily;

    // A "+ pastor" rung with no youth pastor in the church reaches exactly as
    // far as the rung below it. Say so rather than imply someone is listening.
    final hasPastor = ref.watch(churchHasYouthPastorProvider).value ?? true;
    final pastorIsMissing = visibility.needsYouthPastor && !hasPastor;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit relationship' : 'Add a person'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            RequiredTextField(
              controller: _name,
              label: 'Name',
              enabled: !_saving,
              emptyMessage: 'Enter their name.',
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _context,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Where do you know them? (optional)',
                helperText: 'School, neighborhood, sports team, etc.',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _nextStep,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Next step (optional)',
                helperText: 'What do you plan to do next?',
                prefixIcon: Icon(Icons.arrow_forward_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.space5),
            Text('Share this with', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space1),
            Text(
              'With nothing ticked, this stays private — only you can see who '
              'you are reaching out to.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space2),
            SharingCheckbox(
              enabled: !_saving,
              value: sharing.withFamily,
              title: EntrySharing.familyLabelFor(role),
              subtitle: 'They can see who you are investing in and cheer you '
                  'on. Guardians and grandparents count as adults.',
              onChanged: (checked) => _setSharing(
                sharing.copyWith(withFamily: checked),
                role,
              ),
            ),
            SharingCheckbox(
              enabled: !_saving,
              value: sharing.withPastor,
              title: EntrySharing.pastorLabelFor(role),
              // Ticking this also ticks the box above, because
              // `entry_visibility` has no "pastor but not my parents" value and
              // the product does not want one. Saying so beats a box that
              // silently moves on its own.
              subtitle: 'Your youth pastor reads these alongside the adults in '
                  'your family, never instead of them.',
              onChanged: (checked) => _setSharing(
                sharing.copyWith(withPastor: checked),
                role,
              ),
            ),
            if (sharesWithNobody) ...[
              const SizedBox(height: AppTheme.space3),
              const NoticeBanner(
                message: 'You are not in a family yet, so nobody can see this '
                    'yet. Set up your family first if you meant to share it.',
              ),
            ],
            if (pastorIsMissing) ...[
              const SizedBox(height: AppTheme.space3),
              const NoticeBanner(
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
                  : Text(widget.isEditing ? 'Save changes' : 'Add person'),
            ),
          ],
        ),
      ),
    );
  }
}

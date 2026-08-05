import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
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
  }

  Future<void> _save() async {
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
          context: _context.text,
          nextStep: _nextStep.text,
        );
      } else {
        await notifier.add(
          name: _name.text,
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
    if (widget.isEditing) {
      final relationships = ref.watch(relationshipListProvider).value;
      final existing = relationships?.where((r) => r.id == widget.relationshipId).firstOrNull;
      if (existing != null) _hydrate(existing);
    }

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
            if (_error != null) ...[
              const SizedBox(height: AppTheme.space4),
              FormErrorBanner(message: _error!),
            ],
            const SizedBox(height: AppTheme.space5),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const ButtonSpinner()
                  : Text(widget.isEditing ? 'Save changes' : 'Add person'),
            ),
            const SizedBox(height: AppTheme.space3),
            Text(
              'Your parents and youth pastor can see your relationships.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/relationship_providers.dart';
import '../domain/relationship_interaction.dart';

class InteractionEditorPage extends ConsumerStatefulWidget {
  const InteractionEditorPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  ConsumerState<InteractionEditorPage> createState() =>
      _InteractionEditorPageState();
}

class _InteractionEditorPageState
    extends ConsumerState<InteractionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();

  InteractionType _type = InteractionType.hangout;
  DateTime _occurredOn = DateTime.now();

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredOn,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _occurredOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(
              relationshipInteractionsProvider(widget.relationshipId).notifier)
          .add(
            interactionType: _type,
            note: _note.text,
            occurredOn: _occurredOn,
          );
      if (mounted) {
        showAppSnack(context, 'Interaction logged.');
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
        title: const Text('Log interaction'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            DropdownButtonFormField<InteractionType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final type in InteractionType.values)
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
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.edit_calendar_outlined),
                ),
                child: Text(DateFormat.yMMMd().format(_occurredOn)),
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
                helperText: 'What did you talk about? How did it go?',
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
                  : const Text('Log interaction'),
            ),
          ],
        ),
      ),
    );
  }
}

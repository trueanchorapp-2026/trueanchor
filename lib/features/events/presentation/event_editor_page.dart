import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/event_providers.dart';
import '../domain/event.dart';

/// Create or edit a church event. Passing [event] switches the page to edit
/// mode; leaving it null creates a new one.
class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({this.event, super.key});

  final Event? event;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();

  DateTime? _startsAt;
  DateTime? _endsAt;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event != null) {
      _title.text = event.title;
      _description.text = event.description ?? '';
      _location.text = event.location ?? '';
      _startsAt = event.startsAt;
      _endsAt = event.endsAt;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final base = initial ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;

    // Opens on the typed HH:MM field rather than the analog dial. Setting an
    // event to 6:30 is a value people already know, not something they want
    // to draw — the dial is still reachable from the toggle for anyone who
    // prefers it.
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final start = _startsAt;
    if (start == null) {
      setState(() => _error = 'Choose when the event starts.');
      return;
    }
    if (_endsAt != null && _endsAt!.isBefore(start)) {
      setState(() => _error = 'The end time cannot be before the start.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(eventListProvider.notifier);
      if (_isEdit) {
        await notifier.edit(
          id: widget.event!.id,
          title: _title.text,
          description: _description.text,
          location: _location.text,
          startsAt: start,
          endsAt: _endsAt,
        );
      } else {
        await notifier.add(
          title: _title.text,
          description: _description.text,
          location: _location.text,
          startsAt: start,
          endsAt: _endsAt,
        );
      }
      if (mounted) {
        showAppSnack(context, _isEdit ? 'Event updated.' : 'Event created.');
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
        title: Text(_isEdit ? 'Edit event' : 'New event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ContentColumn(
          children: [
            TextFormField(
              controller: _title,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Event name',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              validator: (value) => (value?.trim().isEmpty ?? true)
                  ? 'Give the event a name.'
                  : null,
            ),
            const SizedBox(height: AppTheme.space4),
            _DateTimeField(
              label: 'Starts',
              value: _startsAt,
              enabled: !_saving,
              onTap: () async {
                final picked = await _pickDateTime(_startsAt);
                if (picked != null) setState(() => _startsAt = picked);
              },
            ),
            const SizedBox(height: AppTheme.space4),
            _DateTimeField(
              label: 'Ends (optional)',
              value: _endsAt,
              enabled: !_saving,
              onClear:
                  _endsAt == null ? null : () => setState(() => _endsAt = null),
              onTap: () async {
                final picked = await _pickDateTime(_endsAt ?? _startsAt);
                if (picked != null) setState(() => _endsAt = picked);
              },
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _location,
              enabled: !_saving,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            TextFormField(
              controller: _description,
              enabled: !_saving,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
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
                  : Text(_isEdit ? 'Save changes' : 'Create event'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable field that opens the date+time pickers and shows the chosen
/// value, with an optional clear affordance for the nullable end time.
class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final text =
        value == null ? 'Not set' : DateFormat.yMMMEd().add_jm().format(value!);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule),
          suffixIcon: onClear == null
              ? const Icon(Icons.edit_calendar_outlined)
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Text(text),
      ),
    );
  }
}

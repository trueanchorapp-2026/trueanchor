import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/community_providers.dart';

class CommunityEventEditorPage extends ConsumerStatefulWidget {
  const CommunityEventEditorPage({super.key});

  @override
  ConsumerState<CommunityEventEditorPage> createState() => _EditorState();
}

class _EditorState extends ConsumerState<CommunityEventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isEnd}) async {
    final now = DateTime.now();
    final initial = isEnd
        ? (_endsAt ?? _startsAt ?? now)
        : (_startsAt ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final picked = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isEnd) {
        _endsAt = picked;
      } else {
        _startsAt = picked;
      }
    });
  }

  Future<void> _save(String communityId) async {
    if (!_formKey.currentState!.validate()) return;
    if (_startsAt == null) {
      setState(() => _error = 'Pick a start date and time.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(communityEventListProvider.notifier).add(
            communityId: communityId,
            title: _title.text,
            description: _description.text,
            location: _location.text,
            startsAt: _startsAt!,
            endsAt: _endsAt,
          );
      if (mounted) {
        showAppSnack(context, 'Event created.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(myMembershipProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New event'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _saving ? null : () => context.pop(),
        ),
      ),
      body: membership.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('Something went wrong.')),
        data: (m) {
          if (m == null) {
            return const Center(child: Text('Not in a community.'));
          }
          return _buildForm(m.communityId);
        },
      ),
    );
  }

  Widget _buildForm(String communityId) {
    final dateFmt = DateFormat.yMMMEd().add_jm();

    return Form(
      key: _formKey,
      child: ContentColumn(
        children: [
          TextFormField(
            controller: _title,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Event title'),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'A title is required.' : null,
          ),
          const SizedBox(height: AppTheme.space4),
          TextFormField(
            controller: _description,
            enabled: !_saving,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppTheme.space4),
          TextFormField(
            controller: _location,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Location (optional)',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: AppTheme.space5),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(_startsAt != null
                ? dateFmt.format(_startsAt!)
                : 'Pick start date & time'),
            subtitle: const Text('Starts at'),
            onTap: _saving ? null : () => _pickDateTime(isEnd: false),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(_endsAt != null
                ? dateFmt.format(_endsAt!)
                : 'Pick end date & time (optional)'),
            subtitle: const Text('Ends at'),
            onTap: _saving ? null : () => _pickDateTime(isEnd: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppTheme.space4),
            NoticeBanner(message: _error!, icon: Icons.error_outline),
          ],
          const SizedBox(height: AppTheme.space5),
          FilledButton(
            onPressed: _saving ? null : () => _save(communityId),
            child: _saving
                ? const ButtonSpinner()
                : const Text('Create event'),
          ),
        ],
      ),
    );
  }
}

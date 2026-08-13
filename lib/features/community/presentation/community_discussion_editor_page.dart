import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/community_providers.dart';

class CommunityDiscussionEditorPage extends ConsumerStatefulWidget {
  const CommunityDiscussionEditorPage({super.key});

  @override
  ConsumerState<CommunityDiscussionEditorPage> createState() =>
      _EditorState();
}

class _EditorState extends ConsumerState<CommunityDiscussionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save(String communityId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(communityDiscussionListProvider.notifier).add(
            communityId: communityId,
            title: _title.text,
            body: _body.text,
          );
      if (mounted) {
        showAppSnack(context, 'Discussion started.');
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
        title: const Text('New discussion'),
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
    return Form(
      key: _formKey,
      child: ContentColumn(
        children: [
          TextFormField(
            controller: _title,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'A title is required.' : null,
          ),
          const SizedBox(height: AppTheme.space4),
          TextFormField(
            controller: _body,
            enabled: !_saving,
            minLines: 6,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What would you like to discuss?',
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                (v?.trim().isEmpty ?? true) ? 'Content is required.' : null,
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
                : const Text('Start discussion'),
          ),
        ],
      ),
    );
  }
}

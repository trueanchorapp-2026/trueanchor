import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/community_providers.dart';
import '../domain/discussion_image.dart';
import 'discussion_images.dart';
import 'topic_tag_widgets.dart';

class CommunityDiscussionEditorPage extends ConsumerStatefulWidget {
  const CommunityDiscussionEditorPage({super.key});

  @override
  ConsumerState<CommunityDiscussionEditorPage> createState() => _EditorState();
}

class _EditorState extends ConsumerState<CommunityDiscussionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _saving = false;
  String? _error;

  final _images = <PendingImage>[];
  var _tagIds = <String>{};

  int get _remaining => DiscussionImages.maxPerEntry - _images.length;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await pickDiscussionImages(_remaining);
    if (picked.isNotEmpty && mounted) setState(() => _images.addAll(picked));
  }

  Future<void> _save(String communityId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(communityDiscussionListProvider.notifier)
          .add(
            communityId: communityId,
            title: _title.text,
            body: _body.text,
            images: _images,
            tagIds: _tagIds.toList(),
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
          const SizedBox(height: AppTheme.space4),
          TagPicker(
            selected: _tagIds,
            enabled: !_saving,
            onChanged: (value) => setState(() => _tagIds = value),
          ),
          const SizedBox(height: AppTheme.space4),
          if (_images.isNotEmpty) ...[
            PendingImageStrip(
              images: _images,
              enabled: !_saving,
              size: 120,
              onRemove: (index) => setState(() => _images.removeAt(index)),
            ),
            const SizedBox(height: AppTheme.space3),
          ],
          OutlinedButton.icon(
            onPressed: _saving || _remaining == 0 ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _remaining == 0
                  ? 'Image limit reached'
                  : 'Add images (${_images.length}/'
                        '${DiscussionImages.maxPerEntry})',
            ),
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

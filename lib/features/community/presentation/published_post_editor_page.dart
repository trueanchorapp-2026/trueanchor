import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/community_providers.dart';
import '../domain/published_post.dart';
import 'topic_tag_widgets.dart';

/// Create or edit a News post or Parent Hub resource.
class PublishedPostEditorPage extends ConsumerStatefulWidget {
  const PublishedPostEditorPage({required this.kind, this.postId, super.key});

  final PublishedKind kind;
  final String? postId;

  bool get isEditing => postId != null;

  @override
  ConsumerState<PublishedPostEditorPage> createState() => _EditorState();
}

class _EditorState extends ConsumerState<PublishedPostEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController();
  Set<String> _tags = {};
  List<String> _originalTags = const [];
  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  bool get _isNews => widget.kind == PublishedKind.news;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  void _hydrate(PublishedPost post) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = post.title;
    _body.text = post.body;
    _link.text = post.linkUrl ?? '';
    _tags = post.tagIds.toSet();
    _originalTags = post.tagIds;
  }

  String? _validateBody(String? value) {
    final empty = value?.trim().isEmpty ?? true;
    if (!empty) return null;
    if (widget.kind.requiresBody) return 'Content is required.';
    if (_link.text.trim().isEmpty) return 'Add a description or a link.';
    return null;
  }

  Future<void> _save(String communityId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier =
          ref.read(publishedPostListProvider(widget.kind).notifier);
      if (widget.isEditing) {
        await notifier.edit(
          postId: widget.postId!,
          title: _title.text,
          body: _body.text,
          linkUrl: _link.text,
        );
        if (!setEquals(_tags, _originalTags.toSet())) {
          await notifier.updateTags(
            postId: widget.postId!,
            tagIds: _tags.toList(),
          );
        }
      } else {
        await notifier.add(
          communityId: communityId,
          title: _title.text,
          body: _body.text,
          linkUrl: _link.text,
          tagIds: _tags.toList(),
        );
      }
      if (mounted) {
        showAppSnack(
          context,
          widget.isEditing
              ? '${widget.kind.label} updated.'
              : (_isNews ? 'News posted.' : 'Resource added.'),
        );
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
    final title = widget.isEditing
        ? (_isNews ? 'Edit news' : 'Edit resource')
        : (_isNews ? 'Post news' : 'Add resource');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          if (widget.isEditing) return _buildForEdit(m.communityId);
          return _buildForm(m.communityId);
        },
      ),
    );
  }

  Widget _buildForEdit(String communityId) {
    final postState =
        ref.watch(postByIdProvider((widget.kind, widget.postId!)));
    return AsyncValueView<PublishedPost?>(
      value: postState,
      onRetry: () =>
          ref.invalidate(postByIdProvider((widget.kind, widget.postId!))),
      builder: (post) {
        if (post == null) {
          return const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'Not found',
            message: 'This post may have been deleted.',
          );
        }
        _hydrate(post);
        return _buildForm(communityId);
      },
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
            minLines: _isNews ? 6 : 3,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _isNews ? 'Content' : 'Description (optional)',
              alignLabelWithHint: true,
            ),
            validator: _validateBody,
          ),
          const SizedBox(height: AppTheme.space4),
          TextFormField(
            controller: _link,
            enabled: !_saving,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Link (optional)',
              hintText: 'https://example.org/article',
              prefixIcon: Icon(Icons.link),
            ),
            validator: (v) => PublishedPost.isValidLink(v)
                ? null
                : 'Enter a web address, like https://example.org.',
          ),
          const SizedBox(height: AppTheme.space4),
          TagPicker(
            selected: _tags,
            enabled: !_saving,
            onChanged: (value) => setState(() => _tags = value),
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
                : Text(widget.isEditing ? 'Save changes' : 'Post'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../application/community_providers.dart';
import '../domain/community_news.dart';

class CommunityNewsEditorPage extends ConsumerStatefulWidget {
  const CommunityNewsEditorPage({this.newsId, super.key});

  final String? newsId;

  bool get isEditing => newsId != null;

  @override
  ConsumerState<CommunityNewsEditorPage> createState() =>
      _CommunityNewsEditorPageState();
}

class _CommunityNewsEditorPageState
    extends ConsumerState<CommunityNewsEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _hydrate(CommunityNewsItem item) {
    if (_hydrated) return;
    _hydrated = true;
    _title.text = item.title;
    _body.text = item.body;
  }

  Future<void> _save(String communityId) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final notifier = ref.read(communityNewsListProvider.notifier);
      if (widget.isEditing) {
        await notifier.edit(
          newsId: widget.newsId!,
          title: _title.text,
          body: _body.text,
        );
      } else {
        await notifier.add(
          communityId: communityId,
          title: _title.text,
          body: _body.text,
        );
      }
      if (mounted) {
        showAppSnack(
            context, widget.isEditing ? 'News updated.' : 'News posted.');
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
        title: Text(widget.isEditing ? 'Edit news' : 'Post news'),
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
    final newsState = ref.watch(communityNewsListProvider);

    return AsyncValueView(
      value: newsState,
      onRetry: () =>
          ref.read(communityNewsListProvider.notifier).refresh(),
      builder: (items) {
        CommunityNewsItem? item;
        for (final candidate in items) {
          if (candidate.id == widget.newsId) item = candidate;
        }
        if (item == null) {
          return const EmptyState(
            icon: Icons.search_off_outlined,
            title: 'Not found',
            message: 'This news item may have been deleted.',
          );
        }
        _hydrate(item);
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
            minLines: 6,
            maxLines: 14,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Content',
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
                : Text(widget.isEditing ? 'Save changes' : 'Post'),
          ),
        ],
      ),
    );
  }
}

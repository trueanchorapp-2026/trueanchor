import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community_discussion.dart';

class CommunityDiscussionDetailPage extends ConsumerStatefulWidget {
  const CommunityDiscussionDetailPage(
      {required this.discussionId, super.key});

  final String discussionId;

  @override
  ConsumerState<CommunityDiscussionDetailPage> createState() =>
      _DetailState();
}

class _DetailState extends ConsumerState<CommunityDiscussionDetailPage> {
  final _replyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(discussionRepliesProvider(widget.discussionId).notifier)
          .add(body: text);
      _replyController.clear();
    } catch (e) {
      if (mounted) showAppSnack(context, '$e', isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final discussions = ref.watch(communityDiscussionListProvider);
    final replies = ref.watch(discussionRepliesProvider(widget.discussionId));

    final discussion = discussions.value
        ?.where((d) => d.id == widget.discussionId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(discussion?.title ?? 'Discussion')),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(
                      discussionRepliesProvider(widget.discussionId).notifier)
                  .refresh(),
              child: CustomScrollView(
                slivers: [
                  if (discussion != null)
                    SliverToBoxAdapter(child: _PostHeader(post: discussion)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.space4),
                      child: Divider(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                  ),
                  replies.when(
                    loading: () => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Could not load replies.')),
                    ),
                    data: (replyList) {
                      if (replyList.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              'No replies yet. Be the first!',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ),
                        );
                      }
                      return SliverList.builder(
                        itemCount: replyList.length,
                        itemBuilder: (context, index) => _ReplyTile(
                          reply: replyList[index],
                          discussionId: widget.discussionId,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _ComposerBar(
            controller: _replyController,
            sending: _sending,
            onSend: _sendReply,
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});

  final CommunityDiscussion post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppTheme.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppTheme.space2),
          Row(
            children: [
              if (post.authorName != null) ...[
                Text(
                  post.authorName!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppTheme.space3),
              ],
              Text(
                DateFormat.yMMMd().format(post.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space4),
          Text(post.body, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _ReplyTile extends ConsumerWidget {
  const _ReplyTile({required this.reply, required this.discussionId});

  final DiscussionReply reply;
  final String discussionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final isAuthor = userId != null && reply.isAuthoredBy(userId);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space4,
        vertical: AppTheme.space2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Text(
              (reply.authorName ?? '?')[0].toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.authorName ?? 'Unknown',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(width: AppTheme.space2),
                    Text(
                      DateFormat.MMMd().format(reply.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (isAuthor) ...[
                      const Spacer(),
                      InkWell(
                        onTap: () => _delete(context, ref),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppTheme.space1),
                Text(reply.body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete reply?',
      message: 'This cannot be undone.',
    );
    if (confirmed) {
      await ref
          .read(discussionRepliesProvider(discussionId).notifier)
          .remove(reply.id);
    }
  }
}

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.space4,
        AppTheme.space2,
        AppTheme.space2,
        AppTheme.space4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Write a reply...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppTheme.space3,
                    vertical: AppTheme.space2,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: AppTheme.space2),
            IconButton.filled(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
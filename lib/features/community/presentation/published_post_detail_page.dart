import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community_discussion.dart';
import '../domain/published_post.dart';
import 'published_post_widgets.dart';
import 'topic_tag_widgets.dart';

/// Full News post or Parent Hub resource. News also lists up to five
/// related community discussions.
class PublishedPostDetailPage extends ConsumerWidget {
  const PublishedPostDetailPage({
    required this.kind,
    required this.postId,
    super.key,
  });

  final PublishedKind kind;
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the list entry so optimistic votes show immediately.
    final listed = ref
        .watch(publishedPostListProvider(kind))
        .value
        ?.where((p) => p.id == postId)
        .firstOrNull;
    final fallback = listed == null
        ? ref.watch(postByIdProvider((kind, postId)))
        : AsyncData<PublishedPost?>(listed);
    final canManage = ref.watch(isCommunityAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(kind.label),
        actions: [
          if (canManage && fallback.value != null)
            PublishedPostMenu(
              post: fallback.value!,
              onDeleted: () => context.pop(),
            ),
        ],
      ),
      body: AsyncValueView<PublishedPost?>(
        value: fallback,
        onRetry: () => ref.invalidate(postByIdProvider((kind, postId))),
        builder: (post) {
          if (post == null) {
            return const Center(
              child: EmptyState(
                icon: Icons.search_off_outlined,
                title: 'Not found',
                message: 'This post may have been deleted.',
              ),
            );
          }
          return _PostBody(post: post);
        },
      ),
    );
  }
}

class _PostBody extends StatelessWidget {
  const _PostBody({required this.post});

  final PublishedPost post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentColumn(
      children: [
        Text(post.title, style: theme.textTheme.titleLarge),
        if (post.tagIds.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space2),
          TagChipRow(tagIds: post.tagIds),
        ],
        if (post.body.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space4),
          SelectableText(post.body, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: AppTheme.space3),
        PublishedPostFooter(post: post),
        if (post.kind == PublishedKind.news) ...[
          const SizedBox(height: AppTheme.space5),
          _RelatedDiscussions(newsId: post.id),
        ],
      ],
    );
  }
}

class _RelatedDiscussions extends ConsumerWidget {
  const _RelatedDiscussions({required this.newsId});

  final String newsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final related = ref.watch(relatedDiscussionsProvider(newsId));
    final theme = Theme.of(context);

    return related.when(
      loading: () => const LinearProgressIndicator(),
      // Related posts are a nice-to-have; don't break the page over them.
      error: (_, _) => const SizedBox.shrink(),
      data: (discussions) {
        if (discussions.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Related discussions', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space2),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, d) in discussions.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    _RelatedTile(discussion: d),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.discussion});

  final CommunityDiscussion discussion;

  @override
  Widget build(BuildContext context) {
    final replies = discussion.replyCount ?? 0;
    return ListTile(
      leading: const Icon(Icons.forum_outlined),
      title: Text(
        discussion.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '$replies ${replies == 1 ? 'reply' : 'replies'} · '
        '▲ ${discussion.votes.upvotes}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context
          .push(Routes.communityDiscussionDetailFor(discussion.id)),
    );
  }
}

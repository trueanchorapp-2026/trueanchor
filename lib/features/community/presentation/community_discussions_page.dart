import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/community_discussion.dart';
import 'discussion_images.dart';
import 'topic_tag_widgets.dart';

class CommunityDiscussionsPage extends ConsumerWidget {
  const CommunityDiscussionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);

    return membership.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) {
          return const Center(
            child: EmptyState(
              icon: Icons.diversity_3_outlined,
              title: 'Not in a community',
              message: 'Join a community to see discussions.',
            ),
          );
        }
        return _DiscussionList(communityId: m.communityId);
      },
    );
  }
}

class _DiscussionList extends ConsumerWidget {
  const _DiscussionList({required this.communityId});

  final String communityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communityDiscussionListProvider);
    final query = ref.watch(discussionQueryProvider);
    final queryNotifier = ref.read(discussionQueryProvider.notifier);
    final insets = feedInsets(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.communityDiscussionNew),
        icon: const Icon(Icons.add),
        label: const Text('New discussion'),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              insets.left,
              AppTheme.space3,
              insets.right,
              0,
            ),
            child: TagFilterBar(
              searchHint: 'Search discussions',
              selectedTagIds: query.tagIds,
              initialText: query.text,
              isFiltered: query.isFiltered,
              sort: query.sort,
              onToggleTag: queryNotifier.toggleTag,
              onTextChanged: queryNotifier.setText,
              onSortChanged: queryNotifier.setSort,
              onClear: queryNotifier.clear,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(communityDiscussionListProvider.notifier).refresh(),
              child: AsyncValueView<List<CommunityDiscussion>>(
                value: state,
                onRetry: () => ref
                    .read(communityDiscussionListProvider.notifier)
                    .refresh(),
                builder: (discussions) {
                  if (discussions.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: query.isFiltered
                              ? EmptyState(
                                  icon: Icons.search_off,
                                  title: 'No matching discussions',
                                  message: 'Try another topic or search.',
                                  action: OutlinedButton(
                                    onPressed: queryNotifier.clear,
                                    child: const Text('Clear filters'),
                                  ),
                                )
                              : const EmptyState(
                                  icon: Icons.forum_outlined,
                                  title: 'No discussions yet',
                                  message: 'Start a discussion about '
                                      'something happening in your '
                                      'community.',
                                ),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: feedInsets(context, bottom: AppTheme.fabClearance)
                        .copyWith(top: AppTheme.space2),
                    itemCount: discussions.length,
                    itemBuilder: (context, index) =>
                        _DiscussionCard(discussion: discussions[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscussionCard extends ConsumerWidget {
  const _DiscussionCard({required this.discussion});

  final CommunityDiscussion discussion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;
    final userId = ref.watch(currentUserIdProvider);
    final isAuthor = userId != null && discussion.isAuthoredBy(userId);
    final isCommunityAdmin =
        ref.watch(myMembershipProvider).value?.isAdmin ?? false;
    final replyCount = discussion.replyCount ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push(Routes.communityDiscussionDetailFor(discussion.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(discussion.title,
                        style: theme.textTheme.titleMedium),
                  ),
                  if (isAuthor || isCommunityAdmin)
                    PopupMenuButton<String>(
                      onSelected: (action) =>
                          _onAction(context, ref, action),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                            value: 'tags', child: Text('Edit topics')),
                        if (isAuthor)
                          const PopupMenuItem(
                              value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              if (discussion.tagIds.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space1),
                TagChipRow(
                  tagIds: discussion.tagIds,
                  onTap: (tagId) {
                    final query = ref.read(discussionQueryProvider);
                    if (!query.tagIds.contains(tagId)) {
                      ref
                          .read(discussionQueryProvider.notifier)
                          .toggleTag(tagId);
                    }
                  },
                ),
              ],
              const SizedBox(height: AppTheme.space2),
              if (discussion.imageUrls.isNotEmpty) ...[
                DiscussionImagePreview(urls: discussion.imageUrls),
                const SizedBox(height: AppTheme.space2),
              ],
              Text(
                discussion.body,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.space3),
              Row(
                children: [
                  if (discussion.authorName != null)
                    Text(discussion.authorName!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onMuted)),
                  const Spacer(),
                  Icon(Icons.chat_bubble_outline, size: 14, color: onMuted),
                  const SizedBox(width: AppTheme.space1),
                  Text(
                    '$replyCount',
                    semanticsLabel:
                        '$replyCount ${replyCount == 1 ? 'reply' : 'replies'}',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: onMuted),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Text(
                    DateFormat.yMMMd().format(discussion.createdAt),
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: onMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'tags') {
      final selected = await showTagPickerSheet(
        context,
        initial: discussion.tagIds.toSet(),
      );
      if (selected == null || !context.mounted) return;
      try {
        await ref
            .read(communityDiscussionListProvider.notifier)
            .updateTags(discussionId: discussion.id, tagIds: selected.toList());
        if (context.mounted) showAppSnack(context, 'Topics updated.');
      } catch (e) {
        if (context.mounted) showAppSnack(context, '$e', isError: true);
      }
      return;
    }
    if (action == 'delete') {
      final confirmed = await confirmDestructive(
        context,
        title: 'Delete discussion?',
        message: 'This will also delete all replies.',
      );
      if (confirmed) {
        await ref
            .read(communityDiscussionListProvider.notifier)
            .remove(discussion.id);
        if (context.mounted) showAppSnack(context, 'Discussion deleted.');
      }
    }
  }
}

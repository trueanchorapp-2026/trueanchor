import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/community_providers.dart';
import '../domain/published_post.dart';
import 'topic_tag_widgets.dart';
import 'vote_widgets.dart';

/// The News or Parent Hub tab: search, topic filter, sort, and the list.
/// Community admins also get a "post" button and per-card management.
class PublishedFeed extends ConsumerWidget {
  const PublishedFeed({required this.kind, super.key});

  final PublishedKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);
    return membership.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) {
          return Center(
            child: EmptyState(
              icon: Icons.diversity_3_outlined,
              title: 'Not in a community',
              message: kind == PublishedKind.news
                  ? 'Join a community to see news and updates.'
                  : 'Join a community to see parent resources.',
            ),
          );
        }
        return _FeedBody(kind: kind);
      },
    );
  }
}

class _FeedBody extends ConsumerWidget {
  const _FeedBody({required this.kind});

  final PublishedKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(publishedPostListProvider(kind));
    final query = ref.watch(postQueryProvider(kind));
    final queryNotifier = ref.read(postQueryProvider(kind).notifier);
    final canManage = ref.watch(isCommunityAdminProvider);
    final insets = feedInsets(context);
    final isNews = kind == PublishedKind.news;

    Future<void> refresh() =>
        ref.read(publishedPostListProvider(kind).notifier).refresh();

    return Scaffold(
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.communityPostNewFor(kind)),
              icon: const Icon(Icons.add),
              label: Text(isNews ? 'Post news' : 'Add resource'),
            )
          : null,
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
              searchHint: isNews ? 'Search news' : 'Search resources',
              selectedTagIds: query.tagIds,
              initialText: query.text,
              isFiltered: query.isFiltered,
              sort: query.sort,
              allowedSorts: kind.sorts,
              onToggleTag: queryNotifier.toggleTag,
              onTextChanged: queryNotifier.setText,
              onSortChanged: queryNotifier.setSort,
              onClear: queryNotifier.clear,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: AsyncValueView<List<PublishedPost>>(
                value: state,
                onRetry: refresh,
                builder: (posts) {
                  if (posts.isEmpty) {
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: query.isFiltered
                              ? EmptyState(
                                  icon: Icons.search_off,
                                  title: isNews
                                      ? 'No matching news'
                                      : 'No matching resources',
                                  message: 'Try another topic or search.',
                                  action: OutlinedButton(
                                    onPressed: queryNotifier.clear,
                                    child: const Text('Clear filters'),
                                  ),
                                )
                              : EmptyState(
                                  icon: isNews
                                      ? Icons.newspaper_outlined
                                      : Icons.library_books_outlined,
                                  title: isNews
                                      ? 'No news yet'
                                      : 'No resources yet',
                                  message: isNews
                                      ? 'Community news and updates will '
                                          'appear here.'
                                      : 'Parent resources will appear here '
                                          'once available.',
                                ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: feedInsets(
                      context,
                      bottom: canManage ? AppTheme.fabClearance : AppTheme.space4,
                    ).copyWith(top: AppTheme.space2),
                    itemCount: posts.length,
                    itemBuilder: (context, index) => PublishedPostCard(
                      post: posts[index],
                      onTagTap: (tagId) {
                        if (!query.tagIds.contains(tagId)) {
                          queryNotifier.toggleTag(tagId);
                        }
                      },
                    ),
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

/// A News or Parent Hub post in a list. Tapping opens the detail page.
class PublishedPostCard extends ConsumerWidget {
  const PublishedPostCard({required this.post, this.onTagTap, super.key});

  final PublishedPost post;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canManage = ref.watch(isCommunityAdminProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push(Routes.communityPostDetailFor(post.kind, post.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child:
                        Text(post.title, style: theme.textTheme.titleMedium),
                  ),
                  if (canManage) PublishedPostMenu(post: post),
                ],
              ),
              if (post.tagIds.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space1),
                TagChipRow(tagIds: post.tagIds, onTap: onTagTap),
              ],
              if (post.body.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space2),
                Text(
                  post.body,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppTheme.space2),
              PublishedPostFooter(post: post),
            ],
          ),
        ),
      ),
    );
  }
}

/// Link button, author/date and votes under a post.
class PublishedPostFooter extends ConsumerWidget {
  const PublishedPostFooter({required this.post, super.key});

  final PublishedPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted =
        theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final byline = [
      if (post.authorName != null) post.authorName!,
      DateFormat.yMMMd().format(post.createdAt),
    ].join(' · ');

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppTheme.space3,
      runSpacing: AppTheme.space1,
      children: [
        VoteBar(
          votes: post.votes,
          onVote: (direction) => ref
              .read(publishedPostListProvider(post.kind).notifier)
              .vote(post, direction),
        ),
        if (post.linkUrl != null) OpenLinkButton(url: post.linkUrl!),
        Text(byline, style: muted),
      ],
    );
  }
}

class OpenLinkButton extends StatelessWidget {
  const OpenLinkButton({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? '';
    return TextButton.icon(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
      ),
      onPressed: () async {
        final uri = Uri.tryParse(url);
        final ok = uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && context.mounted) {
          showAppSnack(context, 'Could not open the link.', isError: true);
        }
      },
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(
        host.isEmpty ? 'Open link' : host.replaceFirst('www.', ''),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Edit / edit topics / delete, for community admins.
class PublishedPostMenu extends ConsumerWidget {
  const PublishedPostMenu({required this.post, this.onDeleted, super.key});

  final PublishedPost post;

  /// Called after a successful delete (e.g. to leave the detail page).
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Manage',
      onSelected: (action) => _onAction(context, ref, action),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('Edit')),
        PopupMenuItem(value: 'tags', child: Text('Edit topics')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(publishedPostListProvider(post.kind).notifier);
    switch (action) {
      case 'edit':
        context.push(Routes.communityPostEditFor(post.kind, post.id));
      case 'tags':
        final selected =
            await showTagPickerSheet(context, initial: post.tagIds.toSet());
        if (selected == null || !context.mounted) return;
        try {
          await notifier.updateTags(postId: post.id, tagIds: selected.toList());
          if (context.mounted) showAppSnack(context, 'Topics updated.');
        } catch (e) {
          if (context.mounted) showAppSnack(context, '$e', isError: true);
        }
      case 'delete':
        final noun = post.kind == PublishedKind.news ? 'news post' : 'resource';
        final confirmed = await confirmDestructive(
          context,
          title: 'Delete $noun?',
          message: 'This cannot be undone.',
        );
        if (!confirmed) return;
        try {
          await notifier.remove(post.id);
          if (context.mounted) {
            showAppSnack(context, '${post.kind.label} deleted.');
            onDeleted?.call();
          }
        } catch (e) {
          if (context.mounted) showAppSnack(context, '$e', isError: true);
        }
    }
  }
}

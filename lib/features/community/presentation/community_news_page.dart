import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/community_providers.dart';
import '../domain/community_membership.dart';
import '../domain/community_news.dart';

class CommunityNewsPage extends ConsumerWidget {
  const CommunityNewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider);

    return membership.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (m) {
        if (m == null) return const _NoMembership();
        return _NewsList(membership: m);
      },
    );
  }
}

class _NoMembership extends StatelessWidget {
  const _NoMembership();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: EmptyState(
        icon: Icons.diversity_3_outlined,
        title: 'Not in a community',
        message: 'Join a community to see news and updates.',
      ),
    );
  }
}

class _NewsList extends ConsumerWidget {
  const _NewsList({required this.membership});

  final CommunityMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsState = ref.watch(communityNewsListProvider);
    final canPost = _canPost(ref, membership);

    return Scaffold(
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              onPressed: () => context.push(
                Routes.communityNewsNew,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Post news'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(communityNewsListProvider.notifier).refresh(),
        child: AsyncValueView<List<CommunityNewsItem>>(
          value: newsState,
          onRetry: () =>
              ref.read(communityNewsListProvider.notifier).refresh(),
          builder: (news) {
            if (news.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const EmptyState(
                      icon: Icons.newspaper_outlined,
                      title: 'No news yet',
                      message:
                          'Community news and updates will appear here.',
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                96,
              ),
              itemCount: news.length,
              itemBuilder: (context, index) =>
                  _NewsCard(item: news[index]),
            );
          },
        ),
      ),
    );
  }

  bool _canPost(WidgetRef ref, CommunityMembership membership) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) return false;
    return membership.isAdmin || profile.role.canManageRegions;
  }
}

class _NewsCard extends ConsumerWidget {
  const _NewsCard({required this.item});

  final CommunityNewsItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(currentUserIdProvider);
    final isAuthor = userId != null && item.isAuthoredBy(userId);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(item.title,
                      style: theme.textTheme.titleMedium),
                ),
                if (isAuthor)
                  PopupMenuButton<String>(
                    onSelected: (action) =>
                        _onAction(context, ref, action),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(item.body, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppTheme.space3),
            Row(
              children: [
                if (item.authorName != null)
                  Text(
                    item.authorName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(item.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    if (action == 'edit') {
      context.push(Routes.communityNewsEditFor(item.id));
    } else if (action == 'delete') {
      final confirmed = await confirmDestructive(
        context,
        title: 'Delete news?',
        message: 'This cannot be undone.',
      );
      if (confirmed) {
        await ref
            .read(communityNewsListProvider.notifier)
            .remove(item.id);
        if (context.mounted) showAppSnack(context, 'News deleted.');
      }
    }
  }
}

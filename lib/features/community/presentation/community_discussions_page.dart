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

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.communityDiscussionNew),
        icon: const Icon(Icons.add),
        label: const Text('New discussion'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(communityDiscussionListProvider.notifier).refresh(),
        child: AsyncValueView<List<CommunityDiscussion>>(
          value: state,
          onRetry: () =>
              ref.read(communityDiscussionListProvider.notifier).refresh(),
          builder: (discussions) {
            if (discussions.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No discussions yet',
                      message: 'Start a discussion about something '
                          'happening in your community.',
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
              itemCount: discussions.length,
              itemBuilder: (context, index) =>
                  _DiscussionCard(discussion: discussions[index]),
            );
          },
        ),
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
                  if (isAuthor)
                    PopupMenuButton<String>(
                      onSelected: (action) =>
                          _onAction(context, ref, action),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.space2),
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

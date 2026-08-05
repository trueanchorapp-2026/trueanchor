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
import '../domain/community_event.dart';
import '../domain/community_membership.dart';

class CommunityEventsPage extends ConsumerWidget {
  const CommunityEventsPage({super.key});

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
              message: 'Join a community to see events.',
            ),
          );
        }
        return _EventList(membership: m);
      },
    );
  }
}

class _EventList extends ConsumerWidget {
  const _EventList({required this.membership});

  final CommunityMembership membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(communityEventListProvider);
    final canCreate = _canCreate(ref, membership);

    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.communityEventNew),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(communityEventListProvider.notifier).refresh(),
        child: AsyncValueView<List<CommunityEvent>>(
          value: eventsState,
          onRetry: () =>
              ref.read(communityEventListProvider.notifier).refresh(),
          builder: (events) {
            if (events.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const EmptyState(
                      icon: Icons.event_outlined,
                      title: 'No events yet',
                      message: 'Community events will appear here.',
                    ),
                  ),
                ),
              );
            }

            final now = DateTime.now();
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.space4,
                AppTheme.space4,
                AppTheme.space4,
                96,
              ),
              itemCount: events.length,
              itemBuilder: (context, index) =>
                  _EventCard(event: events[index], isPast: events[index].isPast(now)),
            );
          },
        ),
      ),
    );
  }

  bool _canCreate(WidgetRef ref, CommunityMembership membership) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null) return false;
    return membership.isAdmin || profile.role.canManageRegions;
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.isPast});

  final CommunityEvent event;
  final bool isPast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;
    final userId = ref.watch(currentUserIdProvider);
    final isCreator = userId != null && event.createdBy == userId;

    return Opacity(
      opacity: isPast ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppTheme.space3),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(event.title,
                        style: theme.textTheme.titleMedium),
                  ),
                  if (isCreator)
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
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: onMuted),
                  const SizedBox(width: AppTheme.space2),
                  Text(
                    DateFormat.yMMMEd().add_jm().format(event.startsAt),
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: onMuted),
                  ),
                ],
              ),
              if (event.location != null) ...[
                const SizedBox(height: AppTheme.space1),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: onMuted),
                    const SizedBox(width: AppTheme.space2),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: onMuted),
                      ),
                    ),
                  ],
                ),
              ],
              if (event.description != null) ...[
                const SizedBox(height: AppTheme.space3),
                Text(event.description!,
                    style: theme.textTheme.bodyMedium),
              ],
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
        title: 'Delete event?',
        message: 'This cannot be undone.',
      );
      if (confirmed) {
        await ref
            .read(communityEventListProvider.notifier)
            .remove(event.id);
        if (context.mounted) showAppSnack(context, 'Event deleted.');
      }
    }
  }
}

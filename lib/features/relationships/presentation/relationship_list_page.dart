import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../journal/presentation/journal_list_page.dart'
    show VisibilityBadge;
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/user_role.dart';
import '../application/relationship_providers.dart';
import '../domain/relationship.dart';

class RelationshipListPage extends ConsumerWidget {
  const RelationshipListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(relationshipListProvider);
    final role = ref.watch(currentProfileProvider).value?.role;
    final userId = ref.watch(currentUserIdProvider);

    // Parents and pastors read; only the youth authors. See
    // `relationships_insert_own` in 0022.
    final canAuthor = role?.canTrackRelationships ?? false;

    return Scaffold(
      floatingActionButton: canAuthor
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.relationshipNew),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Add person'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(relationshipListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: listState,
          onRetry: () =>
              ref.read(relationshipListProvider.notifier).refresh(),
          builder: (relationships) {
            if (relationships.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: EmptyState(
                      icon: Icons.favorite_outline,
                      title: canAuthor
                          ? 'No love in action yet'
                          : 'Nothing shared yet',
                      message: _emptyMessageFor(role),
                    ),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: feedInsets(
                context,
                bottom: canAuthor ? AppTheme.fabClearance : AppTheme.space4,
              ),
              itemCount: relationships.length,
              itemBuilder: (context, index) => _RelationshipCard(
                relationship: relationships[index],
                isMine: relationships[index].isOwnedBy(userId),
              ),
            );
          },
        ),
      ),
    );
  }

  /// An empty list means something different to each reader: the youth has not
  /// started, while a parent or pastor may simply not have been let in.
  static String _emptyMessageFor(UserRole? role) => switch (role) {
        UserRole.youthPastor =>
          'When youth in your church share who they are reaching out to, it '
              'will show up here.',
        _ => 'Start tracking a relationship — a neighbor, coworker, or '
            "someone you're praying for. Log interactions to see your "
            'outward investment grow.',
      };
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.relationship, required this.isMine});

  final Relationship relationship;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push(Routes.relationshipDetailFor(relationship.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      relationship.name.isNotEmpty
                          ? relationship.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relationship.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (relationship.context != null) ...[
                          const SizedBox(height: AppTheme.space1),
                          Text(
                            relationship.context!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: onMuted),
                          ),
                        ],
                        if (relationship.nextStep != null) ...[
                          const SizedBox(height: AppTheme.space1),
                          Text(
                            'Next: ${relationship.nextStep!}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    DateFormat.MMMd().format(relationship.updatedAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: onMuted),
                  ),
                  const SizedBox(width: AppTheme.space1),
                  Icon(Icons.chevron_right, color: onMuted),
                ],
              ),
              // On your own list every card is yours and the labels are noise.
              // A parent's list mixes their teenagers together, so it needs to
              // say whose this is and how far the youth chose to share it.
              if (!isMine) ...[
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: AppTheme.space2,
                  runSpacing: AppTheme.space1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppChip(
                      label: relationship.ownerName ?? 'A youth in your church',
                      icon: Icons.person_outline,
                      muted: true,
                    ),
                    VisibilityBadge(visibility: relationship.visibility),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

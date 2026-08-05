import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/relationship_providers.dart';
import '../domain/relationship.dart';

class RelationshipListPage extends ConsumerWidget {
  const RelationshipListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(relationshipListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.relationshipNew),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add person'),
      ),
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
                    child: const EmptyState(
                      icon: Icons.favorite_outline,
                      title: 'No love in action yet',
                      message:
                          'Start tracking a relationship — a classmate you '
                          "want to befriend, someone you're praying for, or "
                          'a person you invited to church.',
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
              itemCount: relationships.length,
              itemBuilder: (context, index) =>
                  _RelationshipCard(relationship: relationships[index]),
            );
          },
        ),
      ),
    );
  }
}

class _RelationshipCard extends StatelessWidget {
  const _RelationshipCard({required this.relationship});

  final Relationship relationship;

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
          child: Row(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat.MMMd().format(relationship.updatedAt),
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: onMuted),
                  ),
                ],
              ),
              const SizedBox(width: AppTheme.space1),
              Icon(Icons.chevron_right, color: onMuted),
            ],
          ),
        ),
      ),
    );
  }
}

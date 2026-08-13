import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../journal/presentation/journal_list_page.dart' show VisibilityBadge;
import '../application/relationship_providers.dart';
import '../domain/relationship.dart';
import '../domain/relationship_interaction.dart';

class RelationshipDetailPage extends ConsumerWidget {
  const RelationshipDetailPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationships = ref.watch(relationshipListProvider);
    final interactionsState =
        ref.watch(relationshipInteractionsProvider(relationshipId));

    final relationship = relationships.value
        ?.where((r) => r.id == relationshipId)
        .firstOrNull;

    // A parent or youth pastor reaches this page through what the youth chose
    // to share. They read it; the youth alone edits, deletes and logs to it.
    final isMine = relationship?.isOwnedBy(ref.watch(currentUserIdProvider))
        // Until the row arrives there is nothing to act on either way.
        ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(relationship?.name ?? 'Relationship'),
        actions: [
          if (isMine) ...[
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(Routes.relationshipEditFor(relationshipId)),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref),
            ),
          ],
        ],
      ),
      floatingActionButton: isMine
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(Routes.interactionNewFor(relationshipId)),
              icon: const Icon(Icons.add),
              label: const Text('Log interaction'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(relationshipInteractionsProvider(relationshipId).notifier)
            .refresh(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            isMine ? 96 : AppTheme.space4, // clears the FAB
          ),
          children: [
            if (relationship != null)
              _InfoSection(relationship: relationship, isMine: isMine),
            const SizedBox(height: AppTheme.space5),
            Text(
              'Interactions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.space3),
            AsyncValueView(
              value: interactionsState,
              onRetry: () => ref
                  .read(
                      relationshipInteractionsProvider(relationshipId).notifier)
                  .refresh(),
              builder: (interactions) {
                if (interactions.isEmpty) {
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTheme.space5),
                    child: EmptyState(
                      icon: Icons.history_outlined,
                      title: 'No interactions yet',
                      message: isMine
                          ? 'Tap "Log interaction" to record time spent '
                              'together.'
                          : 'Nothing has been logged for this person yet.',
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final interaction in interactions)
                      _InteractionTile(
                        interaction: interaction,
                        relationshipId: relationshipId,
                        isMine: isMine,
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this relationship?',
      message:
          'All interactions will also be removed. This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(relationshipListProvider.notifier).remove(relationshipId);
      if (context.mounted) {
        showAppSnack(context, 'Relationship deleted.');
        context.pop();
      }
    } catch (error) {
      if (context.mounted) showAppSnack(context, '$error', isError: true);
    }
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.relationship, required this.isMine});

  final Relationship relationship;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    relationship.name.isNotEmpty
                        ? relationship.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 20,
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
                        style: theme.textTheme.titleLarge,
                      ),
                      if (relationship.context != null)
                        Text(
                          relationship.context!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: onMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (relationship.nextStep != null) ...[
              const SizedBox(height: AppTheme.space3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward_outlined,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      relationship.nextStep!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Whose this is, and how far they chose to share it. On your own
            // entry both facts are already obvious — the editor says them.
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
    );
  }
}

class _InteractionTile extends ConsumerWidget {
  const _InteractionTile({
    required this.interaction,
    required this.relationshipId,
    required this.isMine,
  });

  final RelationshipInteraction interaction;
  final String relationshipId;
  final bool isMine;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this interaction?',
      message: 'This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref
          .read(relationshipInteractionsProvider(relationshipId).notifier)
          .remove(interaction.id);
      if (context.mounted) showAppSnack(context, 'Interaction deleted.');
    } catch (error) {
      if (context.mounted) showAppSnack(context, '$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(
                interaction.interactionType.icon,
                size: 16,
                color: theme.colorScheme.onSecondaryContainer,
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
                        interaction.interactionType.label,
                        style: theme.textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        DateFormat.MMMd().format(interaction.occurredOn),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: onMuted),
                      ),
                    ],
                  ),
                  if (interaction.note != null) ...[
                    const SizedBox(height: AppTheme.space1),
                    Text(
                      interaction.note!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            if (isMine)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: () => _delete(context, ref),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

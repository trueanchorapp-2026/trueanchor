import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/journal_providers.dart';
import '../domain/journal_entry.dart';

class JournalListPage extends ConsumerWidget {
  const JournalListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesState = ref.watch(journalListProvider);
    final userId = ref.watch(currentProfileProvider).value?.id;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.journalNew),
        icon: const Icon(Icons.add),
        label: const Text('New entry'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(journalListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: entriesState,
          onRetry: () => ref.read(journalListProvider.notifier).refresh(),
          builder: (entries) {
            if (entries.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'Nothing here yet',
                      message:
                          'Write your first journal entry or prayer. New '
                          'entries are private until you choose to share them.',
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
                96, // clears the FAB
              ),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _EntryCard(
                  entry: entry,
                  isMine: userId != null && entry.isAuthoredBy(userId),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard({required this.entry, required this.isMine});

  final JournalEntry entry;
  final bool isMine;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this entry?',
      message: 'This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(journalListProvider.notifier).remove(entry.id);
      if (context.mounted) showAppSnack(context, 'Entry deleted.');
    } catch (error) {
      if (context.mounted) {
        showAppSnack(context, '$error', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateLabel = DateFormat.yMMMd().add_jm().format(entry.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  entry.entryType == EntryType.prayer
                      ? Icons.volunteer_activism_outlined
                      : Icons.edit_note_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    entry.displayTitle,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMine)
                  IconButton(
                    tooltip: 'Delete entry',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _delete(context, ref),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(
              entry.body,
              style: theme.textTheme.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.space3),
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                VisibilityBadge(visibility: entry.visibility),
                Text(
                  dateLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (!isMine)
                  Text(
                    '· shared with you',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Makes the sharing state of an entry legible at a glance — the whole point
/// of the visibility feature is that a youth can tell, without opening it,
/// who can read what.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({required this.visibility, super.key});

  final EntryVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPrivate = visibility.isPrivate;
    final background =
        isPrivate ? scheme.surfaceContainerHighest : scheme.secondaryContainer;
    final foreground =
        isPrivate ? scheme.onSurfaceVariant : scheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate ? Icons.lock_outline : Icons.group_outlined,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            visibility.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

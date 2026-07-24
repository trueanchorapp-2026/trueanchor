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
                      // Deliberately not "private until you share": that
                      // stopped being true for parents, whose entries start
                      // with the other adults in their household.
                      message:
                          'Write your first journal entry or prayer. New '
                          'entries start at their narrowest setting until '
                          'you choose to share them further.',
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

enum _EntryAction { edit, delete }

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
                // Only private entries are marked. A badge that is always
                // present says nothing; this one means "no one but you".
                if (entry.visibility.isPrivate) ...[
                  Tooltip(
                    message: 'Private — only you can see this',
                    child: Icon(
                      Icons.visibility_off_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                ],
                Expanded(
                  child: Text(
                    entry.displayTitle,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isMine)
                  PopupMenuButton<_EntryAction>(
                    tooltip: 'Entry actions',
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (action) => switch (action) {
                      _EntryAction.edit =>
                        context.push(Routes.journalEditFor(entry.id)),
                      _EntryAction.delete => _delete(context, ref),
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _EntryAction.edit,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined, size: 20),
                          title: Text('Edit'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _EntryAction.delete,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline, size: 20),
                          title: Text('Delete'),
                        ),
                      ),
                    ],
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
                AppChip(label: entry.entryType.label, muted: true),
                // Authorship is a chip on both sides rather than a chip for
                // others and nothing for yourself: in a family feed the
                // question "is this mine?" is asked of every card, and an
                // absent label answers it only if you already know the rule.
                // Yours is the unmuted one, so the feed reads at a glance.
                AppChip(
                  label: isMine ? 'You' : (entry.authorName ?? 'Someone in your family'),
                  icon: Icons.person_outline,
                  muted: !isMine,
                ),
                // Private is already shown by the icon beside the title;
                // repeating it here would be noise. Shared states are spelled
                // out, because "who exactly can read this" is the one thing
                // worth being explicit about.
                if (!entry.visibility.isPrivate)
                  VisibilityBadge(visibility: entry.visibility),
                Text(
                  dateLabel,
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
    final isPrivate = visibility.isPrivate;
    return AppChip(
      label: visibility.label,
      icon: isPrivate
          ? Icons.visibility_off_outlined
          : Icons.group_outlined,
      muted: isPrivate,
    );
  }
}

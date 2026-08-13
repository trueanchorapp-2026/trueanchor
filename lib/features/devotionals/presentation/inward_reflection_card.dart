import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../journal/application/journal_providers.dart';
import '../../journal/domain/journal_entry.dart';
import '../../profile/application/profile_providers.dart';

class InwardReflectionCard extends ConsumerWidget {
  const InwardReflectionCard({required this.devotionalId, super.key});

  final String devotionalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null || !profile.role.tracksDailyProgress) {
      return const SizedBox.shrink();
    }

    final entriesState = ref.watch(journalListProvider);
    final userId = ref.watch(currentUserIdProvider);

    return entriesState.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.space4),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (entries) {
        final entry = entries
            .where((e) =>
                e.devotionalId == devotionalId && e.authorId == userId)
            .firstOrNull;

        if (entry != null) {
          return _SavedReflection(
            entry: entry,
            onEdit: () => context.push(Routes.journalEditFor(entry.id)),
          );
        }

        return FilledButton.tonalIcon(
          onPressed: () => context.push(
            Routes.journalNewFor(devotionalId: devotionalId, type: 'journal'),
          ),
          icon: const Icon(Icons.edit_note_outlined),
          label: const Text('Write your reflection'),
        );
      },
    );
  }
}

class _SavedReflection extends StatelessWidget {
  const _SavedReflection({required this.entry, required this.onEdit});

  final JournalEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Text(
                    'Your reflection',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            Text(entry.body, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

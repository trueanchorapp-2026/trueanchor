import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../application/milestone_providers.dart';
import '../domain/milestone.dart';

class MilestoneListPage extends ConsumerWidget {
  const MilestoneListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestonesState = ref.watch(milestoneListProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final canRecord = profile?.role.canRecordMilestone ?? false;

    return Scaffold(
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.milestoneNew),
              icon: const Icon(Icons.add),
              label: const Text('Record'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.read(milestoneListProvider.notifier).refresh(),
        child: AsyncValueView(
          value: milestonesState,
          onRetry: () => ref.read(milestoneListProvider.notifier).refresh(),
          builder: (milestones) {
            if (milestones.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: EmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: 'No milestones yet',
                      message: canRecord
                          ? 'Record a first step of faith — accepting Christ, '
                              'baptism, a memory verse — to celebrate it here.'
                          : 'Milestones your parents or church record will '
                              'appear here.',
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
              itemCount: milestones.length,
              itemBuilder: (context, index) => _MilestoneCard(
                milestone: milestones[index],
                canManage: canRecord,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MilestoneCard extends ConsumerWidget {
  const _MilestoneCard({required this.milestone, required this.canManage});

  final Milestone milestone;
  final bool canManage;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this milestone?',
      message: 'This cannot be undone.',
    );
    if (!confirmed) return;

    try {
      await ref.read(milestoneListProvider.notifier).remove(milestone.id);
      if (context.mounted) showAppSnack(context, 'Milestone deleted.');
    } catch (error) {
      if (context.mounted) showAppSnack(context, '$error', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space3),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                milestone.milestoneType.icon,
                size: 20,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppTheme.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          milestone.displayTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (milestone.autoLogged) ...[
                        const SizedBox(width: AppTheme.space2),
                        const AppChip(label: 'From profile'),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.space1),
                  Text(
                    [
                      if (milestone.subjectName != null) milestone.subjectName!,
                      DateFormat.yMMMd().format(milestone.achievedOn),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(color: onMuted),
                  ),
                  if (milestone.note != null) ...[
                    const SizedBox(height: AppTheme.space2),
                    Text(milestone.note!, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            if (canManage)
              IconButton(
                tooltip: 'Delete milestone',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _delete(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../messaging/application/messaging_providers.dart';
import '../../milestones/application/milestone_providers.dart';
import '../../milestones/domain/milestone.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/presentation/progress_day_grid.dart';
import '../application/engagement_providers.dart';
import '../domain/youth_engagement.dart';
import 'weekly_summary_card.dart';

/// One youth, in enough detail for a pastor to decide what to do about them.
class YouthEngagementDetailPage extends ConsumerWidget {
  const YouthEngagementDetailPage({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final youth = ref.watch(youthEngagementProvider(profileId));
    final history = ref.watch(progressForProfileProvider(profileId));

    return Scaffold(
      appBar: AppBar(title: Text(youth?.displayName ?? 'Youth')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _message(context, ref),
        icon: const Icon(Icons.forum_outlined),
        label: const Text('Message'),
      ),
      body: AsyncValueView(
        value: history,
        onRetry: () => ref.invalidate(progressForProfileProvider(profileId)),
        builder: (entries) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.space4,
            AppTheme.space4,
            AppTheme.space4,
            96, // clears the FAB
          ),
          children: [
            if (youth != null) _Headline(youth: youth),
            const SizedBox(height: AppTheme.space5),
            Text(
              'This week',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.space3),
            // Fetched by id, not read off the roster: `youthEngagementProvider`
            // returns null on a cold deep-link, and this card should still
            // fill in.
            WeeklySummaryCard(profileId: profileId),
            const SizedBox(height: AppTheme.space5),
            Text(
              'Last 30 days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.space3),
            ProgressDayGrid(entries: entries),
            const SizedBox(height: AppTheme.space5),
            Text(
              'Milestones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.space2),
            _Milestones(profileId: profileId),
          ],
        ),
      ),
    );
  }

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    try {
      // A pastor must always name the member; `open_thread()` refuses a null
      // partner for their role.
      final thread = await ref
          .read(threadListProvider.notifier)
          .open(withId: profileId);
      if (context.mounted) {
        context.push(Routes.messageThreadFor(thread.id));
      }
    } on AppException catch (error) {
      if (context.mounted) {
        showAppSnack(context, error.message, isError: true);
      }
    }
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.youth});

  final YouthEngagement youth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = youth.grade;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    youth.displayName,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                AppChip(
                  label: youth.status.label,
                  muted: !youth.needsAttention,
                ),
              ],
            ),
            if (grade != null) ...[
              const SizedBox(height: 2),
              Text('Grade $grade', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppTheme.space4),
            Row(
              children: [
                StatTile(value: '${youth.currentStreak}', label: 'Day streak'),
                StatTile(value: '${youth.longestStreak}', label: 'Longest'),
                StatTile(
                    value: '${youth.activeLastSeven}/7', label: 'This week'),
                StatTile(
                    value: '${youth.activeLastThirty}/30', label: 'This month'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Milestones extends ConsumerWidget {
  const _Milestones({required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final milestones = ref.watch(milestoneListProvider);

    return AsyncValueView(
      value: milestones,
      builder: (all) {
        // Filtered from the list the pastor already has rather than fetched
        // again: `milestones_select` scopes it to their church anyway.
        final mine =
            all.where((m) => m.profileId == profileId).toList();
        if (mine.isEmpty) {
          return Text(
            'Nothing recorded yet.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          children: [
            for (final milestone in mine) _MilestoneLine(milestone: milestone),
          ],
        );
      },
    );
  }
}

class _MilestoneLine extends StatelessWidget {
  const _MilestoneLine({required this.milestone});

  final Milestone milestone;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(milestone.milestoneType.icon),
      title: Text(milestone.displayTitle),
      subtitle: Text(DateFormat.yMMMd().format(milestone.achievedOn)),
    );
  }
}

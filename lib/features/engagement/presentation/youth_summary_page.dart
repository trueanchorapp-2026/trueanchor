import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../milestones/application/milestone_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/presentation/progress_day_grid.dart';
import 'weekly_summary_card.dart';

/// One youth of the household, in the detail a parent needs for a conversation.
///
/// The pastor's equivalent is `YouthEngagementDetailPage`. This one has no
/// "Message" action on purpose: pastoral messaging is a pastor's affordance,
/// and a parent already lives with the person on this screen.
class YouthSummaryPage extends ConsumerWidget {
  const YouthSummaryPage({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(familyMembersProvider).value ?? const [];
    final youth =
        members.where((member) => member.id == profileId).firstOrNull;
    final history = ref.watch(progressForProfileProvider(profileId));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          youth == null || youth.fullName.isEmpty ? 'Youth' : youth.fullName,
        ),
      ),
      body: AsyncValueView(
        value: history,
        onRetry: () => ref.invalidate(progressForProfileProvider(profileId)),
        builder: (entries) => ListView(
          padding: const EdgeInsets.all(AppTheme.space4),
          children: [
            Text('This week', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space3),
            WeeklySummaryCard(profileId: profileId),
            const SizedBox(height: AppTheme.space5),
            Text('Last 30 days', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space3),
            ProgressDayGrid(entries: entries),
            const SizedBox(height: AppTheme.space5),
            Text('Milestones', style: theme.textTheme.titleMedium),
            const SizedBox(height: AppTheme.space2),
            _Milestones(profileId: profileId),
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
        // Filtered from the list already in memory rather than fetched again:
        // `milestones_select_parents` scopes it to the family anyway.
        final mine = all.where((m) => m.profileId == profileId).toList();
        if (mine.isEmpty) {
          return Text(
            'Nothing recorded yet.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          children: [
            for (final milestone in mine)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(milestone.milestoneType.icon),
                title: Text(milestone.displayTitle),
                subtitle:
                    Text(DateFormat.yMMMd().format(milestone.achievedOn)),
              ),
          ],
        );
      },
    );
  }
}

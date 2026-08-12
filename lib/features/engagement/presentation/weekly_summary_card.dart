import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/engagement_providers.dart';

/// One youth's last seven days, for whoever is allowed to ask: the youth
/// themself, their parents, or their youth pastor.
///
/// Numbers only, and that is the design. A parent seeing "3 journals" learns
/// their child is writing without being handed anything their child chose to
/// keep private — the counts come from a definer function that never returns
/// entry content. Use it to start a conversation, not to replace one.
class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({required this.profileId, super.key});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = ref.watch(weeklySummaryProvider(profileId));

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: AsyncValueView(
          value: summary,
          onRetry: () => ref.invalidate(weeklySummaryProvider(profileId)),
          builder: (week) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatTile(value: '${week.devotions}', label: 'Devotions'),
                  StatTile(value: '${week.journals}', label: 'Journals'),
                  StatTile(value: '${week.prayers}', label: 'Prayers'),
                  StatTile(value: '${week.currentStreak}', label: 'Day streak'),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              Row(
                children: [
                  Icon(
                    Icons.favorite_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Expanded(
                    child: Text(
                      week.interactions == 1
                          ? '1 Love in Action interaction logged'
                          : '${week.interactions} Love in Action interactions '
                              'logged',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
              // A row of zeros reads like a verdict. Say what it actually
              // means: seven quiet days, nothing more.
              if (week.isEmpty) ...[
                const SizedBox(height: AppTheme.space3),
                const NoticeBanner(
                  message: 'Nothing recorded in the last seven days yet.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

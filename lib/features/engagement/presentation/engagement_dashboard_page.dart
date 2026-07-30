import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/engagement_providers.dart';
import '../domain/youth_engagement.dart';

/// What a youth pastor opens the app to: who is quiet, and for how long.
class EngagementDashboardPage extends ConsumerWidget {
  const EngagementDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(engagementOverviewProvider);

    return RefreshIndicator(
      onRefresh: () => ref.read(engagementOverviewProvider.notifier).refresh(),
      child: AsyncValueView(
        value: overview,
        onRetry: () => ref.read(engagementOverviewProvider.notifier).refresh(),
        builder: (roster) {
          if (roster.isEmpty) {
            return LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: const EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No youth yet',
                    message: 'Once families in your church add youth to their '
                        'households, their devotional engagement appears here.',
                  ),
                ),
              ),
            );
          }

          final needsAttention =
              roster.where((youth) => youth.needsAttention).toList();
          // The roster arrives most-concerning-first, so the same list read
          // straight through is the full-roster section.
          return ListView(
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              _SummaryRow(roster: roster, needingAttention: needsAttention),
              const SizedBox(height: AppTheme.space5),
              if (needsAttention.isNotEmpty) ...[
                _SectionHeading(
                  'Needs attention',
                  trailing: '${needsAttention.length}',
                ),
                for (final youth in needsAttention) _YouthTile(youth: youth),
                const SizedBox(height: AppTheme.space5),
              ],
              const _SectionHeading('All youth'),
              for (final youth in roster) _YouthTile(youth: youth),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.roster, required this.needingAttention});

  final List<YouthEngagement> roster;
  final List<YouthEngagement> needingAttention;

  @override
  Widget build(BuildContext context) {
    final engagedThisWeek =
        roster.where((youth) => youth.activeLastSeven > 0).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            value: '${roster.length}',
            label: 'Youth',
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: _SummaryTile(
            value: '$engagedThisWeek',
            label: 'Active this week',
          ),
        ),
        const SizedBox(width: AppTheme.space3),
        Expanded(
          child: _SummaryTile(
            value: '${needingAttention.length}',
            label: 'Need attention',
            emphasised: needingAttention.isNotEmpty,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.value,
    required this.label,
    this.emphasised = false,
  });

  final String value;
  final String label;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: emphasised ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: emphasised ? scheme.onErrorContainer : null,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: emphasised
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.space2),
      child: Row(
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.space2),
            AppChip(label: trailing!),
          ],
        ],
      ),
    );
  }
}

class _YouthTile extends StatelessWidget {
  const _YouthTile({required this.youth});

  final YouthEngagement youth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = youth.grade;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.space2),
      child: ListTile(
        title: Text(youth.displayName),
        subtitle: Text(
          [
            if (grade != null) 'Grade $grade',
            _lastSeen(youth),
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppChip(
              label: youth.status.label,
              muted: !youth.needsAttention,
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push(Routes.dashboardYouthFor(youth.profileId)),
      ),
    );
  }
}

String _lastSeen(YouthEngagement youth) {
  final days = youth.daysSinceActive;
  if (days == null) return 'Never checked in';
  if (days == 0) return 'Active today';
  if (days == 1) return 'Active yesterday';
  return '$days days ago';
}

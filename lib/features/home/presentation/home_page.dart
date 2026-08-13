import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../devotionals/application/devotional_providers.dart';
import '../../engagement/application/engagement_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../application/home_feed_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.space4),
      children: const [
        _GreetingHeader(),
        SizedBox(height: AppTheme.space4),
        _DevotionalCard(),
        SizedBox(height: AppTheme.space3),
        _StreakCard(),
        SizedBox(height: AppTheme.space3),
        _UpcomingEventsCard(),
        SizedBox(height: AppTheme.space3),
        _DisengagementAlertCard(),
      ],
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = profile?.firstName ?? '';

    return Text(
      name.isEmpty ? '$greeting!' : '$greeting, $name!',
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}

class _DevotionalCard extends ConsumerWidget {
  const _DevotionalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null || !profile.role.tracksDailyProgress) {
      return const SizedBox.shrink();
    }

    final devotional = ref.watch(todaysDevotionalProvider).value;
    if (devotional == null) return const SizedBox.shrink();

    final progress = ref.watch(todayProgressProvider);
    final done = progress?.devotionalDone ?? false;
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go(Routes.today),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.menu_book_outlined,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? 'Devotional complete'
                          : "Today's devotional is ready",
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      devotional.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!done)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null || !profile.role.tracksDailyProgress) {
      return const SizedBox.shrink();
    }

    final streak = ref.watch(progressStreakProvider);
    final theme = Theme.of(context);

    String? subtitle;
    if (streak.isAtRisk) {
      subtitle =
          'Your streak is at risk, but every day is a fresh start.';
    } else if (!streak.engagedToday) {
      subtitle = 'Open today\'s devotional to keep your streak going.';
    }

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go(Routes.today),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_outlined,
                color: streak.current > 0
                    ? Colors.orange
                    : theme.colorScheme.onSurfaceVariant,
                size: 32,
              ),
              const SizedBox(width: AppTheme.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(streak.headline, style: theme.textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventsCard extends ConsumerWidget {
  const _UpcomingEventsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider);
    if (events.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final dateFormat = DateFormat.MMMEd();
    final timeFormat = DateFormat.jm();

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
                  Icons.event_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppTheme.space2),
                Text('Upcoming', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            for (final event in events)
              InkWell(
                onTap: () => context.go(Routes.events),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.space2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppTheme.space2),
                      Text(
                        '${dateFormat.format(event.startsAt)}, '
                        '${timeFormat.format(event.startsAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DisengagementAlertCard extends ConsumerWidget {
  const _DisengagementAlertCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    if (profile == null || !profile.role.canViewEngagementDashboard) {
      return const SizedBox.shrink();
    }

    final atRisk = ref.watch(needsAttentionProvider);
    if (atRisk.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => context.go(Routes.dashboard),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_outlined,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Text(
                    'Youth needing attention (${atRisk.length})',
                    style: theme.textTheme.titleSmall,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              for (final youth in atRisk.take(3))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.space1),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          youth.displayName,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        youth.status.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              if (atRisk.length > 3) ...[
                const SizedBox(height: AppTheme.space2),
                Text(
                  '+ ${atRisk.length - 3} more',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

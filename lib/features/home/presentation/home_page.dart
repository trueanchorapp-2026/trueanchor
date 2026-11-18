import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/scenic_header.dart';
import '../../devotionals/application/devotional_providers.dart';
import '../../engagement/application/engagement_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../application/home_feed_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ContentList(
      children: [
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
    final devotional = ref.watch(todaysDevotionalProvider).value;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final name = profile?.firstName ?? '';

    return ScenicHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.MMMMEEEEd().format(now),
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.space1),
          Text(
            name.isEmpty ? '$greeting!' : '$greeting, $name!',
            style: theme.textTheme.headlineSmall,
          ),
          if (devotional != null) ...[
            const SizedBox(height: AppTheme.space3),
            Text(
              devotional.scriptureText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: AppTheme.serifFamily,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppTheme.space1),
            Text(
              devotional.attribution,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;

    // The day's primary action, so it carries the strongest fill on the page
    // until it is done.
    return SectionCard(
      icon: done ? Icons.check_circle : Icons.menu_book_outlined,
      iconColor: done ? scheme.primary : scheme.onPrimaryContainer,
      color: done ? null : scheme.primaryContainer,
      title: done ? 'Devotional complete' : "Today's devotional is ready",
      subtitle: devotional.title,
      onTap: () => context.go(Routes.today),
      trailing: done
          ? null
          : FilledButton(
              style: AppTheme.inlineButtonStyle,
              onPressed: () => context.go(Routes.today),
              child: const Text('Start'),
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
    final scheme = Theme.of(context).colorScheme;

    String? subtitle;
    if (streak.isAtRisk) {
      subtitle =
          'Your streak is at risk, but every day is a fresh start.';
    } else if (!streak.engagedToday) {
      subtitle = 'Open today\'s devotional to keep your streak going.';
    }

    return SectionCard(
      icon: Icons.local_fire_department_outlined,
      iconColor:
          streak.current > 0 ? scheme.tertiary : scheme.onSurfaceVariant,
      title: streak.headline,
      subtitle: subtitle,
      onTap: () => context.go(Routes.today),
      trailing: const SizedBox.shrink(),
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

    return SectionCard(
      icon: Icons.event_outlined,
      title: 'Upcoming',
      child: Column(
        children: [
          for (final event in events)
            InkWell(
              onTap: () => context.go(Routes.events),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
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
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SectionCard(
      icon: Icons.warning_amber_outlined,
      iconColor: theme.colorScheme.error,
      title: 'Youth needing attention (${atRisk.length})',
      onTap: () => context.go(Routes.dashboard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  Text(youth.status.label, style: muted),
                ],
              ),
            ),
          if (atRisk.length > 3) ...[
            const SizedBox(height: AppTheme.space2),
            Text('+ ${atRisk.length - 3} more', style: muted),
          ],
        ],
      ),
    );
  }
}

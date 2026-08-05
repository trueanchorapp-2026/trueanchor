import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../profile/application/profile_providers.dart';
import '../../progress/presentation/progress_check_card.dart';
import '../application/devotional_providers.dart';
import '../domain/devotional.dart';
import 'devotional_view.dart';
import 'inward_reflection_card.dart';

/// The daily discipleship screen: today's devotional with Verse, Upward,
/// Inward (inline journal/prayer), and Outward sections.
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devotional = ref.watch(todaysDevotionalProvider);

    Future<void> refresh() async {
      ref.invalidate(todaysDevotionalProvider);
      await ref.read(todaysDevotionalProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: AsyncValueView<Devotional?>(
        value: devotional,
        onRetry: () => ref.invalidate(todaysDevotionalProvider),
        builder: (data) {
          if (data == null) return const _EmptyDay();
          return _DevotionalScroll(devotional: data);
        },
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.space5),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppTheme.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: constraints.maxHeight / 2,
                  child: const EmptyState(
                    icon: Icons.wb_sunny_outlined,
                    title: 'No devotional yet',
                    message: 'There is nothing published to read today. '
                        'Check back soon.',
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                const ProgressCheckCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DevotionalScroll extends ConsumerWidget {
  const _DevotionalScroll({required this.devotional});

  final Devotional devotional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = devotional.isForToday(today);
    final profile = ref.watch(currentProfileProvider).value;
    final isYouth = profile?.role.canTrackRelationships ?? false;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppTheme.space5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMEd().format(devotional.publishOn),
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space3),
              if (!isToday) ...[
                const NoticeBanner(
                  message:
                      'Nothing was published for today, so this is the most '
                      'recent devotional.',
                ),
                const SizedBox(height: AppTheme.space4),
              ],
              DevotionalView(
                devotional: devotional,
                inwardChild: InwardReflectionCard(
                  devotionalId: devotional.id,
                ),
                outwardChild: isYouth
                    ? FilledButton.tonalIcon(
                        onPressed: () => context.go(Routes.relationships),
                        icon: const Icon(Icons.favorite_outline),
                        label: const Text('Log Love in Action'),
                      )
                    : null,
                prayerChild: Text(
                  'Take a moment to pray about what you read today. Ask God '
                  'to help you live it out.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              const ProgressCheckCard(),
            ],
          ),
        ),
      ),
    );
  }
}

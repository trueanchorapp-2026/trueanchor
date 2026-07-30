import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../progress/presentation/progress_check_card.dart';
import '../application/devotional_providers.dart';
import '../domain/devotional.dart';
import 'devotional_view.dart';

/// The home screen: today's devotional.
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

/// Nothing has ever been published. The check-offs stay: reading Scripture on
/// paper counts, and a youth should not lose a day because the content
/// calendar has a hole in it.
class _EmptyDay extends StatelessWidget {
  const _EmptyDay();

  @override
  Widget build(BuildContext context) {
    // Keep the scrollable so pull-to-refresh still works on an empty day,
    // matching the journal and milestone lists.
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

class _DevotionalScroll extends StatelessWidget {
  const _DevotionalScroll({required this.devotional});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final isToday = devotional.isForToday(today);

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
              // Say plainly when this is not today's reading rather than
              // passing an older devotional off as the current one.
              if (!isToday) ...[
                const NoticeBanner(
                  message:
                      'Nothing was published for today, so this is the most '
                      'recent devotional.',
                ),
                const SizedBox(height: AppTheme.space4),
              ],
              DevotionalView(devotional: devotional),
              const SizedBox(height: AppTheme.space5),
              // The card sits under the reading, not above it: you check off
              // what you did, having done it.
              const ProgressCheckCard(),
            ],
          ),
        ),
      ),
    );
  }
}

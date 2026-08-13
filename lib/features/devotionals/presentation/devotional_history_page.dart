import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/devotional_providers.dart';
import '../domain/devotional.dart';
import 'devotional_detail_page.dart';

/// Scrollable list of past devotionals. Tapping one opens the full devotional
/// with the user's saved Inward Reflection.
class DevotionalHistoryPage extends ConsumerWidget {
  const DevotionalHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(devotionalHistoryProvider);

    Future<void> refresh() async {
      ref.invalidate(devotionalHistoryProvider);
      await ref.read(devotionalHistoryProvider.future);
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: AsyncValueView<List<Devotional>>(
        value: history,
        onRetry: () => ref.invalidate(devotionalHistoryProvider),
        builder: (devotionals) {
          if (devotionals.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(AppTheme.space5),
                child: EmptyState(
                  icon: Icons.history_outlined,
                  title: 'No devotionals yet',
                  message: 'Past devotionals will appear here.',
                ),
              ),
            );
          }

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppTheme.space4),
            itemCount: devotionals.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space2),
            itemBuilder: (context, index) {
              final devo = devotionals[index];
              return _DevotionalTile(devotional: devo);
            },
          );
        },
      ),
    );
  }
}

class _DevotionalTile extends StatelessWidget {
  const _DevotionalTile({required this.devotional});

  final Devotional devotional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(
          devotional.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          DateFormat.yMMMEd().format(devotional.publishOn),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: Text(
          devotional.scriptureReference,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DevotionalDetailPage(devotional: devotional),
          ),
        ),
      ),
    );
  }
}

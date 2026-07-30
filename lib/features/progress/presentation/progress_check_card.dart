import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../application/progress_providers.dart';
import '../domain/daily_progress.dart';

/// The two check-offs on the Today screen, plus the streak line.
///
/// Renders nothing at all for roles that keep no progress record — church staff
/// read the same devotional but have no streak of their own.
class ProgressCheckCard extends ConsumerStatefulWidget {
  const ProgressCheckCard({super.key});

  @override
  ConsumerState<ProgressCheckCard> createState() => _ProgressCheckCardState();
}

class _ProgressCheckCardState extends ConsumerState<ProgressCheckCard> {
  bool _saving = false;

  Future<void> _set({bool? devotional, bool? scripture}) async {
    final today = ref.read(todayProgressProvider);
    if (today == null || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(recentProgressProvider.notifier).setToday(
            devotionalDone: devotional ?? today.devotionalDone,
            scriptureDone: scripture ?? today.scriptureDone,
          );
    } on AppException catch (error) {
      // The notifier writes before it touches local state, so the boxes are
      // still showing the database's version. Say what happened and leave them
      // alone.
      if (mounted) showAppSnack(context, error.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProgressProvider);
    if (today == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final streak = ref.watch(progressStreakProvider);

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
                  child: Text('Today', style: theme.textTheme.titleMedium),
                ),
                if (_saving)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            _Check(
              label: 'I read the devotional',
              value: today.devotionalDone,
              enabled: !_saving,
              onChanged: (value) => _set(devotional: value),
            ),
            _Check(
              label: 'I read Scripture',
              value: today.scriptureDone,
              enabled: !_saving,
              onChanged: (value) => _set(scripture: value),
            ),
            const SizedBox(height: AppTheme.space2),
            _StreakLine(entry: today, headline: streak.headline),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // CheckboxListTile rather than a bare Checkbox: the whole row is the tap
    // target, which matters most on a phone.
    return CheckboxListTile(
      value: value,
      onChanged: enabled ? (checked) => onChanged(checked ?? false) : null,
      title: Text(label),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class _StreakLine extends StatelessWidget {
  const _StreakLine({required this.entry, required this.headline});

  final DailyProgress entry;
  final String headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          Icons.local_fire_department_outlined,
          size: 18,
          color: entry.engaged
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppTheme.space2),
        Text(
          headline,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/daily_progress.dart';

/// Thirty squares, oldest left. A shape, not a table: the question being asked
/// here is "has this gone patchy recently", which a row of dots answers faster
/// than a list of dates.
///
/// Shared by the youth pastor's drill-down and the parent's youth summary —
/// both are looking at the same thirty days and should see the same picture.
class ProgressDayGrid extends StatelessWidget {
  const ProgressDayGrid({required this.entries, super.key});

  final List<DailyProgress> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final engaged = {
      for (final entry in entries)
        if (entry.engaged)
          DateTime.utc(entry.onDate.year, entry.onDate.month, entry.onDate.day),
    };

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (var back = 29; back >= 0; back--)
          Builder(
            builder: (context) {
              final day = today.subtract(Duration(days: back));
              final key = DateTime.utc(day.year, day.month, day.day);
              final done = engaged.contains(key);
              return Tooltip(
                message:
                    '${DateFormat.MMMd().format(day)} — ${done ? 'engaged' : 'nothing recorded'}',
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color:
                        done ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

import 'devotional.dart';
import 'devotional_audience.dart';

/// The audiences to query for a reader who prefers [preferred]: their own,
/// plus youth content as the fallback every reader may see.
Set<DevotionalAudience> audiencesFor(DevotionalAudience preferred) =>
    {preferred, DevotionalAudience.youth};

/// Picks the devotional to show from [rows] (any order, already limited to
/// [audiencesFor] and to dates on or before the target day).
///
/// The most recent date wins; on a tie the [preferred] audience wins. Fresh
/// youth content therefore beats a stale adult devotional, and an adult reads
/// the youth week until an adult devotional exists for that date.
Devotional? pickForAudience(
  Iterable<Devotional> rows,
  DevotionalAudience preferred,
) {
  Devotional? best;
  for (final row in rows) {
    if (best == null || _better(row, best, preferred)) best = row;
  }
  return best;
}

/// Collapses [rows] to one devotional per date (preferring [preferred]),
/// most recent first — the history list.
List<Devotional> dedupeHistory(
  Iterable<Devotional> rows,
  DevotionalAudience preferred,
) {
  final byDate = <DateTime, Devotional>{};
  for (final row in rows) {
    final key = DateTime(
      row.publishOn.year,
      row.publishOn.month,
      row.publishOn.day,
    );
    final current = byDate[key];
    if (current == null ||
        (row.audience == preferred && current.audience != preferred)) {
      byDate[key] = row;
    }
  }
  return byDate.values.toList()
    ..sort((a, b) => b.publishOn.compareTo(a.publishOn));
}

bool _better(Devotional a, Devotional b, DevotionalAudience preferred) {
  final byDate = a.publishOn.compareTo(b.publishOn);
  if (byDate != 0) return byDate > 0;
  return a.audience == preferred && b.audience != preferred;
}

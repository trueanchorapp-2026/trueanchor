import 'daily_progress.dart';

/// A person's engagement history reduced to the four numbers the app shows.
///
/// This is a deliberate mirror of `private.progress_streak()` in the 0011
/// migration, and the two must stay in step. The division of labour: the SQL is
/// authoritative — it drives the auto-milestone in 0012 and the pastor
/// dashboard in 0015 — while this class is display-only, and only ever for the
/// signed-in user's own rows, which the app has already fetched. Computing it
/// here saves a round trip on the most visited screen in the app and keeps the
/// rule under unit test.
class ProgressStreak {
  const ProgressStreak({
    required this.current,
    required this.longest,
    required this.missedLastSeven,
    required this.engagedToday,
  });

  /// Same island-grouping as the SQL: sort the engaged days, then break them
  /// into runs wherever consecutive dates are more than one day apart.
  factory ProgressStreak.from(
    List<DailyProgress> entries, {
    required DateTime asOf,
  }) {
    final today = _dayOf(asOf);

    final days = entries
        .where((entry) => entry.engaged)
        .map((entry) => _dayOf(entry.onDate))
        .where((day) => !day.isAfter(today))
        .toSet()
        .toList()
      ..sort();

    if (days.isEmpty) {
      return const ProgressStreak(
        current: 0,
        longest: 0,
        missedLastSeven: 7,
        engagedToday: false,
      );
    }

    var longest = 0;
    var runLength = 0;
    DateTime? previous;
    var currentRun = 0;

    for (final day in days) {
      runLength = (previous != null && _daysBetween(previous, day) == 1)
          ? runLength + 1
          : 1;
      if (runLength > longest) longest = runLength;
      previous = day;
      currentRun = runLength;
    }

    // A run counts as *current* only if it reaches today or yesterday. Someone
    // who simply has not opened the app yet this morning keeps their streak;
    // someone who missed all of yesterday has broken it.
    final gap = _daysBetween(days.last, today);
    final current = gap <= 1 ? currentRun : 0;

    final engagedInLastSeven =
        days.where((day) => _daysBetween(day, today) < 7).length;

    return ProgressStreak(
      current: current,
      longest: longest,
      missedLastSeven: 7 - engagedInLastSeven,
      engagedToday: gap == 0,
    );
  }

  final int current;
  final int longest;

  /// Days in the last seven — today included — with no engagement recorded. A
  /// day with no row at all counts as missed: the absence is the point.
  final int missedLastSeven;

  final bool engagedToday;

  /// The threshold the youth pastor dashboard treats as worth a look. Kept
  /// here so the number lives in one place.
  bool get isAtRisk => missedLastSeven >= 3;

  /// The one line shown under the check-offs. Written to encourage rather than
  /// scold: a broken streak reports what is there to build on, not the failure.
  String get headline {
    if (current > 1) return '$current-day streak';
    if (engagedToday) return 'Streak started today';
    if (longest > 0) return 'Longest streak: $longest days';
    return 'Check in to start a streak';
  }
}

/// Normalises to a UTC midnight. UTC only as a fixed-length-day trick: a local
/// midnight on a daylight-saving boundary is 23 or 25 hours from its
/// neighbour, which would make `inDays` below round a consecutive pair to 0 or
/// a gap to 1 and silently corrupt a streak twice a year.
DateTime _dayOf(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

int _daysBetween(DateTime from, DateTime to) =>
    to.difference(from).inDays;

/// One youth's last seven days, as returned by `youth_weekly_summary()`.
///
/// Counts only — deliberately. The RPC is `security definer` so these totals
/// include entries the reader is not allowed to open, which is what makes them
/// honest: a parent's number does not move when their teenager changes a
/// sharing setting. Nothing here can be turned back into content.
class WeeklySummary {
  const WeeklySummary({
    required this.devotions,
    required this.scripture,
    required this.journals,
    required this.prayers,
    required this.interactions,
    required this.currentStreak,
  });

  /// Nulls read as zero: a youth with no rows at all is a legitimate answer,
  /// not a malformed one, and it is the reading a parent most needs to see.
  factory WeeklySummary.fromJson(Map<String, dynamic> json) => WeeklySummary(
        devotions: json['devotions'] as int? ?? 0,
        scripture: json['scripture'] as int? ?? 0,
        journals: json['journals'] as int? ?? 0,
        prayers: json['prayers'] as int? ?? 0,
        interactions: json['interactions'] as int? ?? 0,
        currentStreak: json['current_streak'] as int? ?? 0,
      );

  static const empty = WeeklySummary(
    devotions: 0,
    scripture: 0,
    journals: 0,
    prayers: 0,
    interactions: 0,
    currentStreak: 0,
  );

  /// Days in the window with the devotional marked done.
  final int devotions;

  /// Days in the window with Scripture reading marked done.
  final int scripture;

  final int journals;
  final int prayers;

  /// Love in Action interactions logged in the window.
  final int interactions;

  /// Consecutive engaged days ending today or yesterday. Looks further back
  /// than the window — it is the one figure here about momentum, not this week.
  final int currentStreak;

  /// Whether the week has anything in it at all. Drives the encouraging empty
  /// copy rather than a wall of zeros.
  bool get isEmpty =>
      devotions == 0 &&
      scripture == 0 &&
      journals == 0 &&
      prayers == 0 &&
      interactions == 0;
}

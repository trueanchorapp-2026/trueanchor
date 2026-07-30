/// How a youth's devotional engagement reads at a glance.
///
/// Not a mirror of anything in Postgres — nothing stores this — so unlike
/// [UserRole] it carries no `wire` value. `youth_engagement_overview()` returns
/// numbers and this enum turns them into a word, which keeps the thresholds
/// unit-testable and lets them change without a migration.
enum EngagementStatus {
  /// Has never checked anything off. Distinct from [dormant] on purpose: a
  /// youth who never started needs an introduction, not a nudge.
  neverStarted('Never started', 4),

  /// Two weeks or more since anything. Past a reminder; worth a conversation.
  dormant('Dormant', 3),

  /// The alert CLAUDE.md names: three or more days missed.
  atRisk('Missed 3+ days', 2),

  /// Still turning up, but thinly — three or fewer days in the last seven.
  slipping('Slipping', 1),

  onTrack('On track', 0);

  const EngagementStatus(this.label, this.severity);

  final String label;

  /// Higher means more concerning. Drives ordering, so it lives with the enum
  /// rather than in a comparator that could disagree with it.
  final int severity;

  bool get needsAttention => severity >= atRisk.severity;
}

/// One row of `youth_engagement_overview()`.
class YouthEngagement {
  const YouthEngagement({
    required this.profileId,
    required this.firstName,
    required this.lastName,
    required this.activeLastSeven,
    required this.activeLastThirty,
    required this.currentStreak,
    required this.longestStreak,
    this.grade,
    this.lastActiveOn,
    this.asOf,
  });

  factory YouthEngagement.fromJson(
    Map<String, dynamic> json, {
    DateTime? asOf,
  }) =>
      YouthEngagement(
        profileId: json['profile_id'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        grade: json['grade'] as int?,
        lastActiveOn: _parseDate(json['last_active_on']),
        activeLastSeven: json['active_last_7'] as int? ?? 0,
        activeLastThirty: json['active_last_30'] as int? ?? 0,
        currentStreak: json['current_streak'] as int? ?? 0,
        longestStreak: json['longest_streak'] as int? ?? 0,
        asOf: asOf,
      );

  final String profileId;
  final String firstName;
  final String lastName;
  final int? grade;

  /// The last day this youth marked a devotional or Scripture reading. Null
  /// means never.
  final DateTime? lastActiveOn;

  final int activeLastSeven;
  final int activeLastThirty;
  final int currentStreak;
  final int longestStreak;

  /// The date the overview was computed against. Held so [daysSinceActive] and
  /// [status] agree with the SQL that produced the counts, rather than drifting
  /// against the clock if the page stays open past midnight.
  final DateTime? asOf;

  String get fullName => [firstName, lastName]
      .where((part) => part.trim().isNotEmpty)
      .join(' ')
      .trim();

  String get displayName => fullName.isEmpty ? 'Youth' : fullName;

  /// Whole days between the last engaged day and the as-of date. Null when
  /// there is no last engaged day at all.
  ///
  /// UTC midnights, for the reason [ProgressStreak] gives: a local midnight on
  /// a daylight-saving boundary is 23 or 25 hours from its neighbour, which
  /// would round a day away.
  int? get daysSinceActive {
    final last = lastActiveOn;
    if (last == null) return null;
    final on = asOf ?? DateTime.now();
    return DateTime.utc(on.year, on.month, on.day)
        .difference(DateTime.utc(last.year, last.month, last.day))
        .inDays;
  }

  EngagementStatus get status {
    final days = daysSinceActive;
    if (days == null) return EngagementStatus.neverStarted;
    if (days >= 14) return EngagementStatus.dormant;
    if (days >= 3) return EngagementStatus.atRisk;
    // Turning up, but only just: fewer than half the week.
    if (activeLastSeven <= 3) return EngagementStatus.slipping;
    return EngagementStatus.onTrack;
  }

  bool get needsAttention => status.needsAttention;

  /// Most concerning first: by status, then by how long they have been gone,
  /// then by name so the order is stable between reloads.
  static int compareByConcern(YouthEngagement a, YouthEngagement b) {
    final bySeverity = b.status.severity.compareTo(a.status.severity);
    if (bySeverity != 0) return bySeverity;

    // A never-started youth has no gap to measure; they sort together and fall
    // through to the name.
    final byGap = (b.daysSinceActive ?? 0).compareTo(a.daysSinceActive ?? 0);
    if (byGap != 0) return byGap;

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}

DateTime? _parseDate(Object? value) {
  final raw = value as String?;
  if (raw == null || raw.isEmpty) return null;
  return DateTime.tryParse(raw);
}

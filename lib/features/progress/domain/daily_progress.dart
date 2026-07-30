/// A row of `public.daily_progress`: what one person did on one day.
///
/// Two booleans, no timings. See the 0011 migration banner for why time in app
/// is deliberately not tracked.
class DailyProgress {
  const DailyProgress({
    required this.id,
    required this.profileId,
    required this.onDate,
    required this.devotionalDone,
    required this.scriptureDone,
    this.devotionalId,
  });

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
        id: json['id'] as String,
        profileId: json['profile_id'] as String,
        devotionalId: json['devotional_id'] as String?,
        onDate: _parseDate(json['on_date'] as String?),
        devotionalDone: json['devotional_done'] as bool? ?? false,
        scriptureDone: json['scripture_done'] as bool? ?? false,
      );

  /// The row the app shows for a day that has never been saved. It has no
  /// database id, so [isUnsaved] is what tells the repository to insert rather
  /// than update — the UI renders an untouched day and a saved-but-unchecked
  /// day identically, which is correct.
  factory DailyProgress.empty({
    required String profileId,
    required DateTime onDate,
    String? devotionalId,
  }) =>
      DailyProgress(
        id: '',
        profileId: profileId,
        devotionalId: devotionalId,
        onDate: DateTime(onDate.year, onDate.month, onDate.day),
        devotionalDone: false,
        scriptureDone: false,
      );

  final String id;
  final String profileId;

  /// Which devotional was on offer that day. Null when none was published, or
  /// when the devotional it pointed at has since been removed.
  final String? devotionalId;

  final DateTime onDate;
  final bool devotionalDone;
  final bool scriptureDone;

  bool get isUnsaved => id.isEmpty;

  /// The streak rule: engaging at all counts. Mirrors the `devotional_done or
  /// scripture_done` test in `private.progress_streak()`.
  bool get engaged => devotionalDone || scriptureDone;

  bool get complete => devotionalDone && scriptureDone;

  bool isOn(DateTime day) =>
      onDate.year == day.year &&
      onDate.month == day.month &&
      onDate.day == day.day;

  DailyProgress copyWith({
    String? id,
    bool? devotionalDone,
    bool? scriptureDone,
    String? devotionalId,
  }) =>
      DailyProgress(
        id: id ?? this.id,
        profileId: profileId,
        devotionalId: devotionalId ?? this.devotionalId,
        onDate: onDate,
        devotionalDone: devotionalDone ?? this.devotionalDone,
        scriptureDone: scriptureDone ?? this.scriptureDone,
      );

  /// Deliberately omits profile_id, church_id and family_id: the
  /// `trg_stamp_progress` trigger sets all three from the caller's own profile.
  /// Sending them would be ignored at best and rejected at worst — the same
  /// contract as `Milestone.toInsertJson`.
  static Map<String, dynamic> toUpsertJson({
    required DateTime onDate,
    required bool devotionalDone,
    required bool scriptureDone,
    String? devotionalId,
  }) =>
      {
        'on_date': _formatDate(onDate),
        'devotional_done': devotionalDone,
        'scripture_done': scriptureDone,
        'devotional_id': devotionalId,
      };
}

/// A Postgres `date` has no time and no zone. Parsing it as a local midnight
/// keeps it on the day it names; the epoch fallback makes a malformed row
/// visibly wrong rather than silently today.
DateTime _parseDate(String? value) {
  final parsed = DateTime.tryParse(value ?? '');
  if (parsed == null) return DateTime(1970);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

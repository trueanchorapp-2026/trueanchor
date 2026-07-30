import 'daily_progress.dart';

abstract interface class ProgressRepository {
  /// The signed-in user's own recent days, newest first. Days with no row are
  /// simply absent — the streak calculation treats absence as a missed day.
  Future<List<DailyProgress>> fetchRecent({int days});

  /// Creates or updates today's row. Which columns the caller may set is
  /// fenced by `progress_upsert_own`; profile_id, church_id and family_id are
  /// stamped by the trigger, so they are not sent.
  Future<DailyProgress> upsert({
    required DateTime onDate,
    required bool devotionalDone,
    required bool scriptureDone,
    String? devotionalId,
  });

  /// Someone else's history, for the parent view and the pastor drill-down.
  /// Returns an empty list when RLS says the caller may not see it — the three
  /// `progress_select_*` policies are the real gate, not this method.
  Future<List<DailyProgress>> fetchFor(String profileId, {int days});
}

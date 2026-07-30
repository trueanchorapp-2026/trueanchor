import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/daily_progress.dart';
import '../domain/progress_repository.dart';

class SupabaseProgressRepository implements ProgressRepository {
  const SupabaseProgressRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, profile_id, devotional_id, on_date, devotional_done, scripture_done';

  @override
  Future<List<DailyProgress>> fetchRecent({int days = 30}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    return fetchFor(userId, days: days);
  }

  @override
  Future<List<DailyProgress>> fetchFor(String profileId,
      {int days = 30}) async {
    try {
      final since = DateTime.now().subtract(Duration(days: days - 1));
      final rows = await _client
          .from('daily_progress')
          .select(_columns)
          .eq('profile_id', profileId)
          .gte('on_date', _formatDate(since))
          .order('on_date', ascending: false);
      return rows.map(DailyProgress.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<DailyProgress> upsert({
    required DateTime onDate,
    required bool devotionalDone,
    required bool scriptureDone,
    String? devotionalId,
  }) async {
    try {
      // onConflict names the daily_progress_key index. Without it PostgREST
      // arbitrates on the primary key, which a row keyed by (profile_id,
      // on_date) has never seen — every check-off would insert a duplicate and
      // hit the unique index instead of updating.
      final row = await _client
          .from('daily_progress')
          .upsert(
            DailyProgress.toUpsertJson(
              onDate: onDate,
              devotionalDone: devotionalDone,
              scriptureDone: scriptureDone,
              devotionalId: devotionalId,
            ),
            onConflict: 'profile_id,on_date',
          )
          .select(_columns)
          .single();
      return DailyProgress.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }
}

/// Postgres `date` columns want a bare yyyy-MM-dd.
String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

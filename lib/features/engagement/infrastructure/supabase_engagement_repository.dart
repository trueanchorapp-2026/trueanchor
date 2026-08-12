import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/engagement_repository.dart';
import '../domain/weekly_summary.dart';
import '../domain/youth_engagement.dart';

class SupabaseEngagementRepository implements EngagementRepository {
  const SupabaseEngagementRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<YouthEngagement>> fetchOverview({DateTime? asOf}) async {
    try {
      final on = asOf ?? DateTime.now();
      final rows = await _client.rpc<List<dynamic>>(
        'youth_engagement_overview',
        params: {'p_as_of': _formatDate(on)},
      );
      return rows
          .cast<Map<String, dynamic>>()
          // The as-of date is handed to every row so the "days since" reading
          // on screen agrees with the counts the database computed against it.
          .map((row) => YouthEngagement.fromJson(row, asOf: on))
          .toList()
        ..sort(YouthEngagement.compareByConcern);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<WeeklySummary> fetchWeeklySummary(
    String profileId, {
    DateTime? asOf,
  }) async {
    try {
      final rows = await _client.rpc<List<dynamic>>(
        'youth_weekly_summary',
        params: {
          'p_profile_id': profileId,
          'p_as_of': _formatDate(asOf ?? DateTime.now()),
        },
      );
      // A set-returning function, so this arrives as a list. It always holds
      // exactly one row — the aggregates are unconditional — but an empty list
      // means a week with nothing in it, not a failure.
      if (rows.isEmpty) return WeeklySummary.empty;
      return WeeklySummary.fromJson(rows.first as Map<String, dynamic>);
    } catch (error) {
      throw mapError(error);
    }
  }
}

/// Postgres `date` parameters want a bare yyyy-MM-dd.
String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

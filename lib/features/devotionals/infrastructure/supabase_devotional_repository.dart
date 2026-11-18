import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/devotional.dart';
import '../domain/devotional_audience.dart';
import '../domain/devotional_repository.dart';
import '../domain/devotional_selection.dart';

class SupabaseDevotionalRepository implements DevotionalRepository {
  const SupabaseDevotionalRepository(this._client);

  final SupabaseClient _client;

  /// The row plus its weekly theme, embedded through theme_id.
  static const _columns = '*, theme:devotional_themes(*)';

  @override
  Future<List<Devotional>> fetchHistory({
    DevotionalAudience audience = DevotionalAudience.youth,
    int limit = 30,
  }) async {
    final audiences = audiencesFor(audience);
    try {
      // Up to one row per audience per date, so over-fetch and collapse.
      final rows = await _client
          .from('devotionals')
          .select(_columns)
          .inFilter('audience', [for (final a in audiences) a.wire])
          .lte('publish_on', _formatDate(DateTime.now()))
          .order('publish_on', ascending: false)
          .limit(limit * audiences.length);
      final history = dedupeHistory(rows.map(Devotional.fromJson), audience);
      return history.length > limit ? history.sublist(0, limit) : history;
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Devotional?> fetchForDate(
    DateTime date, {
    DevotionalAudience audience = DevotionalAudience.youth,
  }) async {
    final audiences = audiencesFor(audience);
    try {
      // The exact-date row and the fallback are the same query: everything on
      // or before the date, newest first. Taking one row per audience covers
      // the case where both audiences share the latest date; the pure
      // pickForAudience then decides. One round trip, served by the
      // (audience, publish_on desc) index.
      final rows = await _client
          .from('devotionals')
          .select(_columns)
          .inFilter('audience', [for (final a in audiences) a.wire])
          .lte('publish_on', _formatDate(date))
          .order('publish_on', ascending: false)
          .limit(audiences.length);
      return pickForAudience(rows.map(Devotional.fromJson), audience);
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

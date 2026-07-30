import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/devotional.dart';
import '../domain/devotional_repository.dart';

class SupabaseDevotionalRepository implements DevotionalRepository {
  const SupabaseDevotionalRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '*';

  @override
  Future<Devotional?> fetchForDate(DateTime date) async {
    try {
      // The exact-date row and the fallback are the same query: order by
      // publish_on descending among everything published on or before the
      // date, and take the first. When today's devotional exists it sorts
      // first; when it does not, the most recent earlier one does. One round
      // trip, served by the publish_on index, and no RPC to grant.
      final row = await _client
          .from('devotionals')
          .select(_columns)
          .lte('publish_on', _formatDate(date))
          .order('publish_on', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : Devotional.fromJson(row);
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

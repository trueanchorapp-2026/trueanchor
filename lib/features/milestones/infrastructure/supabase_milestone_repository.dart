import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/milestone.dart';
import '../domain/milestone_repository.dart';

class SupabaseMilestoneRepository implements MilestoneRepository {
  const SupabaseMilestoneRepository(this._client);

  final SupabaseClient _client;

  // Join the subject's name so parents/staff can tell whose milestone it is.
  // `profiles!profile_id` disambiguates from the recorded_by foreign key.
  static const _columns =
      '*, subject:profiles!profile_id(first_name, last_name)';

  @override
  Future<List<Milestone>> fetchVisible() async {
    try {
      final rows = await _client
          .from('milestones')
          .select(_columns)
          .order('achieved_on', ascending: false);
      return rows.map(Milestone.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Milestone> create({
    required String profileId,
    required MilestoneType milestoneType,
    required String? title,
    required String? note,
    required DateTime achievedOn,
  }) async {
    try {
      final row = await _client
          .from('milestones')
          .insert(
            Milestone.toInsertJson(
              profileId: profileId,
              milestoneType: milestoneType,
              title: title,
              note: note,
              achievedOn: achievedOn,
            ),
          )
          .select(_columns)
          .single();
      return Milestone.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('milestones').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }
}

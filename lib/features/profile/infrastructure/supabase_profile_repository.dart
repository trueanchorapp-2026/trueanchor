import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/family_role.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns = '*';

  @override
  Future<Profile?> fetchMine(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select(_columns)
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Profile.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Profile> update(Profile profile) async {
    try {
      final row = await _client
          .from('profiles')
          .update(profile.toUpdateJson())
          .eq('id', profile.id)
          .select(_columns)
          .single();
      return Profile.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<Profile>> fetchFamilyMembers(String familyId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_columns)
          .eq('family_id', familyId)
          .order('role')
          .order('first_name');
      return rows.map(Profile.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Profile> setFamilyRole(String memberId, FamilyRole role) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'set_family_member_role',
        params: {'p_member': memberId, 'p_family_role': role.wire},
      );
      return Profile.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }
}

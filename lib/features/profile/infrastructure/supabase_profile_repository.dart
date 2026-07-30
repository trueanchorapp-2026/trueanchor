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
          // Parents above youth, then A->Z. public.user_role is declared
          // ('app_admin','church_admin','youth_pastor','parent','youth'), so
          // ascending is what puts the adults first -- and it has to be spelled
          // out, because postgrest-dart defaults it to FALSE unlike supabase-js.
          .order('role', ascending: true)
          .order('first_name', ascending: true);
      return rows.map(Profile.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<Profile>> fetchChurchMembers(String churchId) async {
    try {
      final rows = await _client
          .from('profiles')
          .select(_columns)
          .eq('church_id', churchId)
          // A->Z; see fetchFamilyMembers on the ascending default.
          .order('last_name', ascending: true)
          .order('first_name', ascending: true);
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

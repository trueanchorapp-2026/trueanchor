import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';

class SupabaseFamilyRepository implements FamilyRepository {
  const SupabaseFamilyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Family?> fetchById(String familyId) async {
    try {
      final row = await _client
          .from('families')
          .select()
          .eq('id', familyId)
          .maybeSingle();
      return row == null ? null : Family.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Family> createFamily(String name) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'create_family',
        params: {'p_name': name.trim()},
      );
      return Family.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Family> joinFamily(String joinCode) async {
    try {
      final row = await _client.rpc<Map<String, dynamic>>(
        'join_family',
        params: {'p_code': joinCode.trim().toUpperCase()},
      );
      return Family.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }
}

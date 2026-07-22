import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../../family/domain/family.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../domain/church.dart';
import '../domain/church_repository.dart';

class SupabaseChurchRepository implements ChurchRepository {
  const SupabaseChurchRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Church?> fetchCurrentChurch() async {
    try {
      // No filter: `churches_select` returns exactly the caller's own church.
      final row = await _client.from('churches').select().maybeSingle();
      return row == null ? null : Church.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<Family>> fetchFamilies() async {
    try {
      final rows = await _client.from('families').select().order('name');
      return rows.map(Family.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<Profile>> fetchDirectory() async {
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .order('last_name')
          .order('first_name');
      return rows.map(Profile.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<ChurchInvite>> fetchInvites() async {
    try {
      final rows = await _client
          .from('church_invites')
          .select()
          .order('created_at', ascending: false);
      return rows.map(ChurchInvite.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<ChurchInvite> createInvite({
    required String code,
    required UserRole role,
    required int maxUses,
    DateTime? expiresAt,
  }) async {
    try {
      // church_id has to be sent explicitly (unlike journal entries, which a
      // trigger stamps). The insert policy checks it against the caller's own
      // church, so a wrong value is refused rather than accepted.
      final church = await fetchCurrentChurch();
      if (church == null) {
        throw const AppException('Could not find your church.');
      }

      final draft = ChurchInvite(
        id: '',
        churchId: church.id,
        code: code,
        role: role,
        maxUses: maxUses,
        uses: 0,
        expiresAt: expiresAt,
      );

      final row = await _client
          .from('church_invites')
          .insert(draft.toInsertJson())
          .select()
          .single();
      return ChurchInvite.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }
}

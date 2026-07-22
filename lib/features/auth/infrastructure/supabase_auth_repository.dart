import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../../profile/domain/user_role.dart';
import '../domain/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<InvitePreview?> validateInviteCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    try {
      final rows = await _client.rpc<List<dynamic>>(
        'validate_invite_code',
        params: {'p_code': trimmed},
      );
      if (rows.isEmpty) return null;

      final row = rows.first as Map<String, dynamic>;
      return InvitePreview(
        churchId: row['church_id'] as String,
        churchName: row['church_name'] as String,
        role: UserRole.fromWire(row['role'] as String),
      );
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String inviteCode,
  }) async {
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: password,
        // Read by private.handle_new_user() to build the profile row.
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'invite_code': inviteCode.trim().toUpperCase(),
        },
      );
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (error) {
      throw mapError(error);
    }
  }
}

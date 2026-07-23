import '../../family/domain/family.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import 'church.dart';

/// Reads for church staff. Every method is church-scoped by RLS rather than by
/// a filter here, so none of them can be pointed at another tenant.
abstract interface class ChurchRepository {
  Future<Church?> fetchCurrentChurch();

  /// Households in the caller's church. Returns empty for a parent or youth:
  /// the `families_select` policy only shows staff the whole church.
  Future<List<Family>> fetchFamilies();

  /// Everyone in the caller's church.
  Future<List<Profile>> fetchDirectory();

  /// Invite codes for the caller's church. Staff only.
  Future<List<ChurchInvite>> fetchInvites();

  /// Issues a new invite code. Church admins only — the `invites_insert`
  /// policy rejects everyone else, and rejects any `church_id` but the
  /// caller's, so a code cannot be minted for another church.
  ///
  /// There is deliberately no revoke here: `church_invites` has select and
  /// insert policies only, so a delete from the client would silently affect
  /// zero rows and look like it worked. Retiring a code is a dashboard job
  /// until a migration adds a delete policy. Setting a low `maxUses` is the
  /// client-side lever in the meantime.
  Future<ChurchInvite> createInvite({
    required String code,
    required UserRole role,
    required int maxUses,
    DateTime? expiresAt,
  });
}

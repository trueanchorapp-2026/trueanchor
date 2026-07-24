import 'family_role.dart';
import 'profile.dart';

abstract interface class ProfileRepository {
  /// The signed-in user's own profile. Null only in the brief window where the
  /// auth user exists but the signup trigger's row is not yet visible.
  Future<Profile?> fetchMine(String userId);

  Future<Profile> update(Profile profile);

  /// Everyone in a family. Used by the family page and by parents reviewing
  /// shared journal entries.
  Future<List<Profile>> fetchFamilyMembers(String familyId);

  /// Everyone in a church. RLS only returns rows to church staff, so this is
  /// used by staff-only flows (e.g. picking a youth to record a milestone for).
  Future<List<Profile>> fetchChurchMembers(String churchId);

  /// Labels a member of the caller's household, which also decides whether the
  /// app treats them as an adult or as youth. Server-side RPC: it refuses
  /// anyone who is not the head of that household, and cannot reach church
  /// roles, so neither check can be skipped by the client.
  Future<Profile> setFamilyRole(String memberId, FamilyRole role);
}

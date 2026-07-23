import 'family.dart';

abstract interface class FamilyRepository {
  Future<Family?> fetchById(String familyId);

  /// Creates a family with the caller as head of household and moves them into
  /// it. Server-side RPC: it also generates the join code and stamps church_id,
  /// so neither can be forged by the client.
  Future<Family> createFamily(String name);

  /// Moves the caller into an existing family. The RPC refuses codes belonging
  /// to another church, so this cannot cross a tenancy boundary.
  Future<Family> joinFamily(String joinCode);
}

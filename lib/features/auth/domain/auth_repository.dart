import '../../profile/domain/user_role.dart';

/// What a church invite code resolves to. Shown on the signup form before the
/// user commits, so they can see which church and role they are joining.
class InvitePreview {
  const InvitePreview({
    required this.churchId,
    required this.churchName,
    required this.role,
  });

  final String churchId;
  final String churchName;
  final UserRole role;
}

abstract interface class AuthRepository {
  /// Resolves a church invite code, or null when it is invalid, expired or
  /// exhausted. Callable while signed out.
  Future<InvitePreview?> validateInviteCode(String code);

  /// Registers a user. The database trigger creates the matching profile row
  /// and resolves church + role from [inviteCode]; an invalid code aborts the
  /// whole signup rather than leaving an orphaned auth user.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String inviteCode,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

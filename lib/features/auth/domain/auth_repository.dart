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

  /// Starts the Google OAuth flow. On web this redirects the whole page, so it
  /// does not resolve to a session here — the app re-initialises on return. A
  /// new Google user comes back with a session but no profile; [claimInvite]
  /// then attaches them to a church.
  Future<void> signInWithGoogle();

  /// Turns a church invite code into the caller's profile row. Used only on the
  /// OAuth path, where the signup trigger could not create the profile because
  /// no code was present at sign-in. Fails if a profile already exists.
  Future<void> claimInvite({
    required String firstName,
    required String lastName,
    required String code,
  });

  Future<void> signOut();
}

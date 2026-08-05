import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/auth_repository.dart';
import '../infrastructure/supabase_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

/// Looks up a church invite code so the signup form can confirm which church
/// and role the user is about to join.
///
/// `isAutoDispose` matters here: without it every keystroke-worth of code the
/// user tries would be retained for the life of the app.
final invitePreviewProvider =
    FutureProvider.family<InvitePreview?, String>(
  isAutoDispose: true,
  // A bad code is a normal outcome, not a transient fault, so don't retry it.
  retry: (_, _) => null,
  (ref, code) => ref.watch(authRepositoryProvider).validateInviteCode(code),
);

/// Drives the sign-in / sign-up / sign-out buttons. The `AsyncValue<void>`
/// state gives pages a uniform way to show a spinner and surface errors
/// without owning any of the logic themselves.
class AuthController extends AsyncNotifier<void> {
  @override
  void build() {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _repo.signIn(email: email, password: password));

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String inviteCode,
  }) =>
      _run(
        () => _repo.signUp(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          inviteCode: inviteCode,
        ),
      );

  Future<void> signInWithGoogle() => _repo.signInWithGoogle();

  Future<bool> claimInvite({
    required String firstName,
    required String lastName,
    required String code,
  }) =>
      _run(
        () => _repo.claimInvite(
          firstName: firstName,
          lastName: lastName,
          code: code,
        ),
      );

  Future<bool> claimRegionalInvite({
    required String firstName,
    required String lastName,
    required String code,
  }) =>
      _run(
        () => _repo.claimRegionalInvite(
          firstName: firstName,
          lastName: lastName,
          code: code,
        ),
      );

  Future<bool> signOut() => _run(() => _repo.signOut());

  /// Returns whether the action succeeded, so callers can decide about
  /// navigation without having to re-inspect [state].
  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

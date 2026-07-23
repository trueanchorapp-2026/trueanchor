import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';
import '../infrastructure/supabase_profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => SupabaseProfileRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's profile, or null when signed out.
///
/// This is the app's central piece of state: the router's redirect ladder, the
/// role-based navigation and every church-scoped query read from it.
class CurrentProfile extends AsyncNotifier<Profile?> {
  @override
  Future<Profile?> build() async {
    // Re-runs on sign-in and sign-out.
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.watch(profileRepositoryProvider).fetchMine(userId);
  }

  /// Persists edits and republishes the saved row.
  ///
  /// Deliberately does not flip to [AsyncLoading] first: the edit page owns its
  /// own submitting flag, and blanking this provider would tear down the whole
  /// signed-in shell that reads from it.
  Future<void> save(Profile updated) async {
    final saved = await ref.read(profileRepositoryProvider).update(updated);
    state = AsyncData(saved);
  }

  /// Re-reads from the database. Used after joining or creating a family,
  /// which changes `family_id` server-side via RPC.
  Future<void> refresh() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = await AsyncValue.guard(
      () => ref.read(profileRepositoryProvider).fetchMine(userId),
    );
  }
}

final currentProfileProvider =
    AsyncNotifierProvider<CurrentProfile, Profile?>(CurrentProfile.new);

/// Members of the signed-in user's family. Empty before family setup.
final familyMembersProvider = FutureProvider<List<Profile>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final familyId = profile?.familyId;
  if (familyId == null) return const [];
  return ref.watch(profileRepositoryProvider).fetchFamilyMembers(familyId);
});

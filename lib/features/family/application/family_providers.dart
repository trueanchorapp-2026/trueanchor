import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/family_role.dart';
import '../domain/family.dart';
import '../domain/family_repository.dart';
import '../infrastructure/supabase_family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => SupabaseFamilyRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's family, or null before setup.
final currentFamilyProvider = FutureProvider<Family?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  final familyId = profile?.familyId;
  if (familyId == null) return null;
  return ref.watch(familyRepositoryProvider).fetchById(familyId);
});

/// Drives the family setup screen's two actions.
class FamilyController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> create(String name) =>
      _run(() => ref.read(familyRepositoryProvider).createFamily(name));

  Future<bool> join(String code) =>
      _run(() => ref.read(familyRepositoryProvider).joinFamily(code));

  Future<bool> _run(Future<Family> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      // Both RPCs change profiles.family_id server-side, so the cached profile
      // is now stale. Refreshing it is what releases the router's family-setup
      // gate.
      await ref.read(currentProfileProvider.notifier).refresh();
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final familyControllerProvider =
    AsyncNotifierProvider<FamilyController, void>(FamilyController.new);

/// Lets the head of household label the people who joined with their code.
class FamilyRoleController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> assign(String memberId, FamilyRole role) async {
    state = const AsyncLoading();
    try {
      await ref.read(profileRepositoryProvider).setFamilyRole(memberId, role);
      ref.invalidate(familyMembersProvider);

      // A head who relabels themselves changes their own permission role,
      // which drives the nav bar and the router — so their cached profile has
      // to be re-read, not just the member list.
      final me = ref.read(currentProfileProvider).value;
      if (me != null && me.id == memberId) {
        await ref.read(currentProfileProvider.notifier).refresh();
      }

      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final familyRoleControllerProvider =
    AsyncNotifierProvider<FamilyRoleController, void>(FamilyRoleController.new);

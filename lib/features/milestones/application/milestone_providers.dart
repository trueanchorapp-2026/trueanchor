import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../domain/milestone.dart';
import '../domain/milestone_repository.dart';
import '../infrastructure/supabase_milestone_repository.dart';

final milestoneRepositoryProvider = Provider<MilestoneRepository>(
  (ref) => SupabaseMilestoneRepository(ref.watch(supabaseClientProvider)),
);

/// Every milestone the signed-in user may read, newest achievement first.
class MilestoneList extends AsyncNotifier<List<Milestone>> {
  @override
  Future<List<Milestone>> build() {
    // Re-runs on sign-out so one family's milestones never leak into the next
    // session.
    ref.watch(currentUserIdProvider);
    return ref.watch(milestoneRepositoryProvider).fetchVisible();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(milestoneRepositoryProvider).fetchVisible(),
    );
  }

  Future<void> add({
    required String profileId,
    required MilestoneType milestoneType,
    required String? title,
    required String? note,
    required DateTime achievedOn,
  }) async {
    final created = await ref.read(milestoneRepositoryProvider).create(
          profileId: profileId,
          milestoneType: milestoneType,
          title: title,
          note: note,
          achievedOn: achievedOn,
        );
    final current = state.value ?? const <Milestone>[];
    state = AsyncData(
      [...current, created]..sort((a, b) => b.achievedOn.compareTo(a.achievedOn)),
    );
  }

  Future<void> remove(String id) async {
    await ref.read(milestoneRepositoryProvider).delete(id);
    final current = state.value ?? const <Milestone>[];
    state = AsyncData(current.where((m) => m.id != id).toList());
  }
}

final milestoneListProvider =
    AsyncNotifierProvider<MilestoneList, List<Milestone>>(MilestoneList.new);

/// The youth a recorder may log a milestone against.
///
/// A parent picks from the youth in their own household; church staff pick from
/// every youth in the church directory (which `profiles_select_church` already
/// exposes to them). Empty for anyone who cannot record.
final milestoneSubjectsProvider = FutureProvider<List<Profile>>((ref) async {
  final me = await ref.watch(currentProfileProvider.future);
  if (me == null || !me.role.canRecordMilestone) return const [];

  final repo = ref.watch(profileRepositoryProvider);
  final List<Profile> people;
  if (me.role == UserRole.parent) {
    final familyId = me.familyId;
    if (familyId == null) return const [];
    people = await repo.fetchFamilyMembers(familyId);
  } else {
    people = await repo.fetchChurchMembers(me.churchId);
  }
  return people.where((p) => p.role == UserRole.youth).toList();
});

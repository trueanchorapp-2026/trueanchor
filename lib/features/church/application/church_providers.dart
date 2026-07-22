import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../family/domain/family.dart';
import '../../profile/application/profile_providers.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import '../domain/church.dart';
import '../domain/church_overview.dart';
import '../domain/church_repository.dart';
import '../infrastructure/supabase_church_repository.dart';

final churchRepositoryProvider = Provider<ChurchRepository>(
  (ref) => SupabaseChurchRepository(ref.watch(supabaseClientProvider)),
);

/// The church directory, assembled for staff.
///
/// The three reads are issued together rather than in sequence — they don't
/// depend on each other, and a pastor on a slow connection shouldn't wait for
/// three round trips.
final churchOverviewProvider = FutureProvider<ChurchOverview?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.role.isChurchStaff) return null;

  final repository = ref.watch(churchRepositoryProvider);
  final results = await Future.wait([
    repository.fetchCurrentChurch(),
    repository.fetchFamilies(),
    repository.fetchDirectory(),
  ]);

  final church = results[0] as Church?;
  if (church == null) return null;

  return ChurchOverview.from(
    church: church,
    families: results[1] as List<Family>,
    people: results[2] as List<Profile>,
  );
});

final churchInvitesProvider = FutureProvider<List<ChurchInvite>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile == null || !profile.role.isChurchStaff) return const [];
  return ref.watch(churchRepositoryProvider).fetchInvites();
});

/// Which roles a code may be issued for.
///
/// `app_admin` is absent on purpose: it is a platform role, not something a
/// single church should be able to hand out.
const issuableInviteRoles = <UserRole>[
  UserRole.parent,
  UserRole.youth,
  UserRole.youthPastor,
  UserRole.churchAdmin,
];

/// Issues invite codes. Only church admins can, but that is enforced by the
/// `invites_insert` policy — this controller just surfaces the refusal.
class InviteController extends AsyncNotifier<void> {
  @override
  void build() {}

  Future<bool> issue({
    required String code,
    required UserRole role,
    required int maxUses,
    DateTime? expiresAt,
  }) async {
    state = const AsyncLoading();
    try {
      final normalized = ChurchInvite.normalizeCode(code);
      if (normalized.isEmpty) {
        throw const AppException('Enter a code, or generate one.');
      }
      if (maxUses < 1) {
        throw const AppException('A code needs at least one use.');
      }
      if (!issuableInviteRoles.contains(role)) {
        throw const AppException('That role cannot be invited by code.');
      }

      await ref.read(churchRepositoryProvider).createInvite(
            code: normalized,
            role: role,
            maxUses: maxUses,
            expiresAt: expiresAt,
          );
      ref.invalidate(churchInvitesProvider);
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      state = AsyncError(error, stack);
      return false;
    }
  }
}

final inviteControllerProvider =
    AsyncNotifierProvider<InviteController, void>(InviteController.new);

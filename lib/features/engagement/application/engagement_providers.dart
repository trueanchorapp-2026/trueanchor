import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/engagement_repository.dart';
import '../domain/youth_engagement.dart';
import '../infrastructure/supabase_engagement_repository.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) => SupabaseEngagementRepository(ref.watch(supabaseClientProvider)),
);

/// Every youth in the pastor's church, most concerning first.
class EngagementOverview extends AsyncNotifier<List<YouthEngagement>> {
  @override
  Future<List<YouthEngagement>> build() async {
    // Re-runs on sign-out, so one church's roster never survives into the next
    // session.
    ref.watch(currentUserIdProvider);

    final profile = await ref.watch(currentProfileProvider.future);
    // Checked before the call, not after: `youth_engagement_overview()` raises
    // NOT_AUTHORIZED rather than returning nothing, so asking anyway would turn
    // a wrong-role visit into an error screen.
    if (profile == null || !profile.role.canViewEngagementDashboard) {
      return const [];
    }

    return ref.watch(engagementRepositoryProvider).fetchOverview();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }
}

final engagementOverviewProvider =
    AsyncNotifierProvider<EngagementOverview, List<YouthEngagement>>(
  EngagementOverview.new,
);

/// The youth who have gone quiet. Drives the "Needs attention" section and the
/// summary tile above it.
final needsAttentionProvider = Provider<List<YouthEngagement>>((ref) {
  final roster = ref.watch(engagementOverviewProvider).value ?? const [];
  return roster.where((youth) => youth.needsAttention).toList();
});

/// One youth's row, for the drill-down page. Reads from the roster already in
/// memory rather than re-running a church-wide aggregate for a single person.
final youthEngagementProvider =
    Provider.family<YouthEngagement?, String>((ref, profileId) {
  final roster = ref.watch(engagementOverviewProvider).value ?? const [];
  for (final youth in roster) {
    if (youth.profileId == profileId) return youth;
  }
  return null;
});

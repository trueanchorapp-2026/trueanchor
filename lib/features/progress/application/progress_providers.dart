import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../devotionals/application/devotional_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/daily_progress.dart';
import '../domain/progress_repository.dart';
import '../domain/progress_streak.dart';
import '../infrastructure/supabase_progress_repository.dart';

/// How much history the app keeps in memory. Enough to draw a month grid and
/// to hold any streak the UI will name, without pulling a year down to the
/// phone on every visit to the Today screen.
const progressWindowDays = 60;

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => SupabaseProgressRepository(ref.watch(supabaseClientProvider)),
);

/// The signed-in user's own recent days.
///
/// Church staff keep no progress record of their own — `tracksDailyProgress`
/// mirrors `progress_upsert_own`, and asking would just return an empty list —
/// so the network call is skipped for them entirely.
class RecentProgress extends AsyncNotifier<List<DailyProgress>> {
  @override
  Future<List<DailyProgress>> build() async {
    // Re-runs on sign-out, so one person's history never survives into the
    // next session.
    ref.watch(currentUserIdProvider);

    final profile = await ref.watch(currentProfileProvider.future);
    if (profile == null || !profile.role.tracksDailyProgress) return const [];

    return ref
        .watch(progressRepositoryProvider)
        .fetchRecent(days: progressWindowDays);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  /// Records today's check-offs.
  ///
  /// The write happens first and local state second, on purpose: a checkbox
  /// must never show a tick the database refused. On failure the exception
  /// propagates with state untouched, and the card reverts.
  Future<void> setToday({
    required bool devotionalDone,
    required bool scriptureDone,
  }) async {
    final today = DateTime.now();
    final saved = await ref.read(progressRepositoryProvider).upsert(
          onDate: today,
          devotionalDone: devotionalDone,
          scriptureDone: scriptureDone,
          devotionalId: ref.read(todaysDevotionalProvider).value?.id,
        );

    final current = state.value ?? const <DailyProgress>[];
    state = AsyncData([
      saved,
      ...current.where((entry) => !entry.isOn(saved.onDate)),
    ]);
  }
}

final recentProgressProvider =
    AsyncNotifierProvider<RecentProgress, List<DailyProgress>>(
  RecentProgress.new,
);

/// Today's row, synthesised locally when nothing has been saved yet so the
/// card always has something to render.
final todayProgressProvider = Provider<DailyProgress?>((ref) {
  final entries = ref.watch(recentProgressProvider).value;
  final userId = ref.watch(currentUserIdProvider);
  if (entries == null || userId == null) return null;

  final today = DateTime.now();
  for (final entry in entries) {
    if (entry.isOn(today)) return entry;
  }
  return DailyProgress.empty(profileId: userId, onDate: today);
});

/// The signed-in user's own streak, computed from rows already in memory.
final progressStreakProvider = Provider<ProgressStreak>((ref) {
  final entries = ref.watch(recentProgressProvider).value ?? const [];
  return ProgressStreak.from(entries, asOf: DateTime.now());
});

/// Someone else's history: a parent looking at their youth, or a youth pastor
/// drilling into one of theirs. RLS decides whether anything comes back.
final progressForProfileProvider =
    FutureProvider.family<List<DailyProgress>, String>((ref, profileId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(progressRepositoryProvider)
      .fetchFor(profileId, days: progressWindowDays);
});

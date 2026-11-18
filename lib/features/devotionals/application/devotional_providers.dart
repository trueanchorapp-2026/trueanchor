import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/devotional.dart';
import '../domain/devotional_audience.dart';
import '../domain/devotional_repository.dart';
import '../infrastructure/supabase_devotional_repository.dart';

final devotionalRepositoryProvider = Provider<DevotionalRepository>(
  (ref) => SupabaseDevotionalRepository(ref.watch(supabaseClientProvider)),
);

/// The devotional track the signed-in reader prefers, from their role. Youth
/// until the profile has loaded — youth content is the track every reader can
/// fall back to.
final devotionalAudienceProvider = Provider<DevotionalAudience>((ref) {
  final role = ref.watch(currentProfileProvider).value?.role;
  return role?.devotionalAudience ?? DevotionalAudience.youth;
});

/// Past devotionals for the history view, most recent first.
final devotionalHistoryProvider = FutureProvider<List<Devotional>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(devotionalRepositoryProvider)
      .fetchHistory(audience: ref.watch(devotionalAudienceProvider));
});

/// The devotional to read today, or the most recent one when today's has not
/// been published. Null when the table is empty.
///
/// "Today" is the device's local date: a youth in California should get their
/// own calendar day, not the server's UTC one.
final todaysDevotionalProvider = FutureProvider<Devotional?>((ref) {
  // Devotionals are global, so this does not need to re-read on sign-out for
  // privacy — but the session does gate the read (`to authenticated`), so the
  // fetch must re-run once a user is actually signed in.
  ref.watch(currentUserIdProvider);
  return ref.watch(devotionalRepositoryProvider).fetchForDate(
        DateTime.now(),
        audience: ref.watch(devotionalAudienceProvider),
      );
});

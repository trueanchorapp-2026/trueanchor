import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/devotional.dart';
import '../domain/devotional_repository.dart';
import '../infrastructure/supabase_devotional_repository.dart';

final devotionalRepositoryProvider = Provider<DevotionalRepository>(
  (ref) => SupabaseDevotionalRepository(ref.watch(supabaseClientProvider)),
);

/// Past devotionals for the history view, most recent first.
final devotionalHistoryProvider = FutureProvider<List<Devotional>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(devotionalRepositoryProvider).fetchHistory();
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
  return ref.watch(devotionalRepositoryProvider).fetchForDate(DateTime.now());
});

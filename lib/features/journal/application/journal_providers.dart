import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/providers/supabase_providers.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';
import '../infrastructure/supabase_journal_repository.dart';

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => SupabaseJournalRepository(ref.watch(supabaseClientProvider)),
);

/// Every entry the signed-in user may read, newest first.
class JournalList extends AsyncNotifier<List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> build() {
    // Re-runs on sign-out so one user's entries never survive into the next
    // session.
    ref.watch(currentUserIdProvider);
    return ref.watch(journalRepositoryProvider).fetchVisible();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(journalRepositoryProvider).fetchVisible(),
    );
  }

  Future<void> add({
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  }) async {
    final authorId = ref.read(currentUserIdProvider);
    if (authorId == null) {
      throw const AppException('You are signed out. Sign in and try again.');
    }

    final created = await ref.read(journalRepositoryProvider).create(
          authorId: authorId,
          title: title,
          body: body,
          entryType: entryType,
          visibility: visibility,
        );

    state = AsyncData([created, ...state.value ?? const []]);
  }

  Future<void> remove(String entryId) async {
    await ref.read(journalRepositoryProvider).delete(entryId);
    final current = state.value ?? const <JournalEntry>[];
    state = AsyncData(
      current.where((entry) => entry.id != entryId).toList(),
    );
  }
}

final journalListProvider =
    AsyncNotifierProvider<JournalList, List<JournalEntry>>(JournalList.new);

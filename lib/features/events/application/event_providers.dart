import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/event.dart';
import '../domain/event_repository.dart';
import '../infrastructure/supabase_event_repository.dart';

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => SupabaseEventRepository(ref.watch(supabaseClientProvider)),
);

/// Every event in the signed-in user's church, ordered by start time.
class EventList extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() {
    // Re-runs on sign-out so one church's calendar never survives into the
    // next session.
    ref.watch(currentUserIdProvider);
    return ref.watch(eventRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(eventRepositoryProvider).fetchAll(),
    );
  }

  Future<void> add({
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    await ref.read(eventRepositoryProvider).create(
          title: title,
          description: description,
          location: location,
          startsAt: startsAt,
          endsAt: endsAt,
        );
    await refresh();
  }

  Future<void> edit({
    required String id,
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    await ref.read(eventRepositoryProvider).update(
          id: id,
          title: title,
          description: description,
          location: location,
          startsAt: startsAt,
          endsAt: endsAt,
        );
    await refresh();
  }

  Future<void> remove(String id) async {
    await ref.read(eventRepositoryProvider).delete(id);
    final current = state.value ?? const <Event>[];
    state = AsyncData(current.where((event) => event.id != id).toList());
  }
}

final eventListProvider =
    AsyncNotifierProvider<EventList, List<Event>>(EventList.new);

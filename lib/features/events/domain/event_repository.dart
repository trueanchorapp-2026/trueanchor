import 'event.dart';

abstract interface class EventRepository {
  /// Every event the signed-in user may read. RLS scopes this to their church;
  /// upcoming events come before past ones, each block ordered by start time.
  Future<List<Event>> fetchAll();

  Future<Event> create({
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  });

  Future<Event> update({
    required String id,
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  });

  Future<void> delete(String id);
}

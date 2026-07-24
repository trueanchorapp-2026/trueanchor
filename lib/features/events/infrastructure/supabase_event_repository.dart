import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/event.dart';
import '../domain/event_repository.dart';

class SupabaseEventRepository implements EventRepository {
  const SupabaseEventRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Event>> fetchAll() async {
    try {
      final rows = await _client
          .from('events')
          .select()
          .order('starts_at', ascending: true);
      return rows.map(Event.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Event> create({
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    try {
      final row = await _client
          .from('events')
          .insert(
            Event.toWriteJson(
              title: title,
              description: description,
              location: location,
              startsAt: startsAt,
              endsAt: endsAt,
            ),
          )
          .select()
          .single();
      return Event.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Event> update({
    required String id,
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) async {
    try {
      final row = await _client
          .from('events')
          .update(
            Event.toWriteJson(
              title: title,
              description: description,
              location: location,
              startsAt: startsAt,
              endsAt: endsAt,
            ),
          )
          .eq('id', id)
          .select()
          .single();
      return Event.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('events').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';

class SupabaseJournalRepository implements JournalRepository {
  const SupabaseJournalRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<JournalEntry>> fetchVisible() async {
    try {
      final rows = await _client
          .from('journal_entries')
          .select()
          .order('created_at', ascending: false);
      return rows.map(JournalEntry.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<JournalEntry> create({
    required String authorId,
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  }) async {
    try {
      final row = await _client
          .from('journal_entries')
          .insert(
            JournalEntry.toInsertJson(
              authorId: authorId,
              title: title,
              body: body,
              entryType: entryType,
              visibility: visibility,
            ),
          )
          .select()
          .single();
      return JournalEntry.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> delete(String entryId) async {
    try {
      await _client.from('journal_entries').delete().eq('id', entryId);
    } catch (error) {
      throw mapError(error);
    }
  }
}

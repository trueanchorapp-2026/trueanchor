import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/app_exception.dart';
import '../domain/journal_entry.dart';
import '../domain/journal_repository.dart';

class SupabaseJournalRepository implements JournalRepository {
  const SupabaseJournalRepository(this._client);

  final SupabaseClient _client;

  /// Pulls the author's name alongside the row so a shared entry can say who
  /// wrote it. A parent of three cannot act on "someone shared this".
  ///
  /// This does not widen access: the embed is itself subject to RLS on
  /// `profiles`, and every reader of an entry can already read that author's
  /// profile. If a policy ever changed, the name would come back null rather
  /// than leak.
  static const _selectWithAuthor =
      '*, author:profiles!author_id(first_name, last_name)';

  @override
  Future<List<JournalEntry>> fetchVisible() async {
    try {
      final rows = await _client
          .from('journal_entries')
          .select(_selectWithAuthor)
          .order('created_at', ascending: false);
      return rows.map(JournalEntry.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<JournalEntry?> fetchForDevotional(String devotionalId) async {
    try {
      final row = await _client
          .from('journal_entries')
          .select()
          .eq('devotional_id', devotionalId)
          .maybeSingle();
      return row == null ? null : JournalEntry.fromJson(row);
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
    String? devotionalId,
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
              devotionalId: devotionalId,
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
  Future<JournalEntry> update({
    required String entryId,
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  }) async {
    try {
      final row = await _client
          .from('journal_entries')
          .update(
            JournalEntry.toUpdateJson(
              title: title,
              body: body,
              entryType: entryType,
              visibility: visibility,
            ),
          )
          .eq('id', entryId)
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

  @override
  Future<bool> churchHasYouthPastor() async {
    try {
      final result = await _client.rpc<dynamic>('church_has_youth_pastor');
      // Assume one on an unreadable answer: a spurious "nobody will see this"
      // warning would talk a user out of sharing something they should.
      return result as bool? ?? true;
    } catch (error) {
      throw mapError(error);
    }
  }
}

import 'journal_entry.dart';

abstract interface class JournalRepository {
  /// Everything the signed-in user is permitted to read.
  ///
  /// There is no filter here on purpose: RLS decides what comes back. A youth
  /// sees their own entries; a parent additionally sees entries their children
  /// shared; a pastor sees only those shared with pastors. The client never
  /// gets rows it should not have, so it never has to hide any.
  Future<List<JournalEntry>> fetchVisible();

  Future<JournalEntry> create({
    required String authorId,
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  });

  Future<void> delete(String entryId);
}

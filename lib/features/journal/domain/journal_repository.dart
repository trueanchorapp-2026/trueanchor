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
    String? devotionalId,
  });

  /// Rewrites an entry the caller authored. Visibility is editable here on
  /// purpose: a sharing decision a user cannot walk back is worse than one
  /// they can. `journal_update_own` refuses every other author's rows.
  Future<JournalEntry> update({
    required String entryId,
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  });

  Future<void> delete(String entryId);

  /// Whether the caller's church has a youth pastor.
  ///
  /// Sharing with a pastor who does not exist reaches nobody, and the editor
  /// should say so before someone writes something vulnerable. A youth cannot
  /// determine this from `profiles` — `profiles_select_family` limits them to
  /// their own household — so this goes through a security-definer function
  /// that returns nothing but the boolean.
  Future<bool> churchHasYouthPastor();
}

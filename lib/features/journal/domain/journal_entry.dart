import '../../../core/domain/entry_visibility.dart';

/// [EntryVisibility] and [EntrySharing] moved to `core/domain` when Love in
/// Action started sharing on the same ladder. Re-exported so journal code —
/// and its tests — still find the whole vocabulary in one import.
export '../../../core/domain/entry_visibility.dart';

/// Mirrors the `public.entry_type` Postgres enum.
enum EntryType {
  journal('journal', 'Journal'),
  prayer('prayer', 'Prayer');

  const EntryType(this.wire, this.label);

  final String wire;
  final String label;

  static EntryType fromWire(String value) => EntryType.values.firstWhere(
        (type) => type.wire == value,
        orElse: () => throw ArgumentError('Unknown entry_type: $value'),
      );

  static EntryType? tryFromWire(String? value) {
    if (value == null) return null;
    for (final type in EntryType.values) {
      if (type.wire == value) return type;
    }
    return null;
  }
}

/// A row of `public.journal_entries`.
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.authorId,
    required this.body,
    required this.entryType,
    required this.visibility,
    required this.createdAt,
    this.title,
    this.familyId,
    this.authorName,
    this.devotionalId,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        authorName: _authorNameFrom(json['author']),
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        entryType: EntryType.fromWire(json['entry_type'] as String),
        visibility: EntryVisibility.fromWire(json['visibility'] as String),
        familyId: json['family_id'] as String?,
        devotionalId: json['devotional_id'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );

  final String id;
  final String authorId;

  /// The author's display name, present only when the query embedded it.
  ///
  /// Null is not an error: inserts and updates return the bare row, and the
  /// UI only needs a name on entries someone *else* wrote. Anyone permitted
  /// to read an entry may also read its author's profile — see
  /// `profiles_select_family` and `profiles_select_staff` in 0006 — so this
  /// embed never widens what RLS already allows.
  final String? authorName;
  final String? title;
  final String body;
  final EntryType entryType;
  final EntryVisibility visibility;
  final String? familyId;
  final String? devotionalId;
  final DateTime createdAt;

  bool isAuthoredBy(String userId) => authorId == userId;

  /// Flattens the embedded `author:profiles(...)` object into a display name.
  /// Tolerates a missing embed, a missing profile, and blank name columns.
  static String? _authorNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    final parts = [embedded['first_name'], embedded['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// A one-line preview for the list. Falls back to the body when untitled.
  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    final firstLine = body.trim().split('\n').first;
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 60)}…';
  }

  /// church_id and family_id are deliberately absent: a database trigger
  /// stamps them from the author's profile so a client cannot post an entry
  /// into another church or household.
  static Map<String, dynamic> toInsertJson({
    required String authorId,
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
    String? devotionalId,
  }) =>
      {
        'author_id': authorId,
        'title': (title?.trim().isEmpty ?? true) ? null : title!.trim(),
        'body': body.trim(),
        'entry_type': entryType.wire,
        'visibility': visibility.wire,
        'devotional_id': ?devotionalId,
      };

  /// author_id, church_id and family_id are absent: an edit must never be able
  /// to move an entry to another author or household. `journal_update_own`
  /// already refuses a change of author; omitting the columns means the client
  /// never even asks.
  static Map<String, dynamic> toUpdateJson({
    required String? title,
    required String body,
    required EntryType entryType,
    required EntryVisibility visibility,
  }) =>
      {
        'title': (title?.trim().isEmpty ?? true) ? null : title!.trim(),
        'body': body.trim(),
        'entry_type': entryType.wire,
        'visibility': visibility.wire,
      };
}

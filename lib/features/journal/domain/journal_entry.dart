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
}

/// Mirrors the `public.entry_visibility` Postgres enum.
///
/// These labels are the user's only window onto a rule enforced in Postgres.
/// If the wording here ever drifts from the RLS policies in
/// `supabase/migrations/0001_init.sql`, the app is lying about privacy — so
/// keep the two in step.
enum EntryVisibility {
  private(
    'private',
    'Private',
    'Only you can see this. Not your parents, not your church.',
  ),
  parents(
    'parents',
    'Share with parents',
    'The parents in your family can read this.',
  ),
  parentsPastor(
    'parents_pastor',
    'Share with parents and pastor',
    'Your parents and your youth pastor can read this.',
  );

  const EntryVisibility(this.wire, this.label, this.description);

  final String wire;
  final String label;
  final String description;

  static EntryVisibility fromWire(String value) =>
      EntryVisibility.values.firstWhere(
        (visibility) => visibility.wire == value,
        orElse: () => throw ArgumentError('Unknown entry_visibility: $value'),
      );

  bool get isPrivate => this == EntryVisibility.private;
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
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        authorId: json['author_id'] as String,
        title: json['title'] as String?,
        body: json['body'] as String? ?? '',
        entryType: EntryType.fromWire(json['entry_type'] as String),
        visibility: EntryVisibility.fromWire(json['visibility'] as String),
        familyId: json['family_id'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
      );

  final String id;
  final String authorId;
  final String? title;
  final String body;
  final EntryType entryType;
  final EntryVisibility visibility;
  final String? familyId;
  final DateTime createdAt;

  bool isAuthoredBy(String userId) => authorId == userId;

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
  }) =>
      {
        'author_id': authorId,
        'title': (title?.trim().isEmpty ?? true) ? null : title!.trim(),
        'body': body.trim(),
        'entry_type': entryType.wire,
        'visibility': visibility.wire,
      };
}

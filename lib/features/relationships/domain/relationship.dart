import '../../../core/domain/entry_visibility.dart';

class Relationship {
  const Relationship({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    this.context,
    this.nextStep,
    this.ownerName,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      ownerName: _ownerNameFrom(json['owner']),
      name: json['name'] as String,
      context: json['context'] as String?,
      nextStep: json['next_step'] as String?,
      visibility: EntryVisibility.fromWire(json['visibility'] as String),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  final String id;
  final String ownerId;

  /// The owning youth's display name, present only when the query embedded it.
  ///
  /// Null is not an error: inserts and updates return the bare row, and the UI
  /// only needs a name on entries someone *else* logged. Anyone permitted to
  /// read a relationship may also read its owner's profile — see
  /// `profiles_select_family` and `profiles_select_staff` in 0006 — so this
  /// embed never widens what RLS already allows.
  final String? ownerName;
  final String name;
  final String? context;
  final String? nextStep;

  /// Who beyond the owner can read this. Enforced in Postgres by
  /// `relationships_select_parents` / `relationships_select_pastor` in 0025;
  /// only the three youth-reachable rungs are ever stored here.
  final EntryVisibility visibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isOwnedBy(String? userId) => userId != null && ownerId == userId;

  /// Flattens the embedded `owner:profiles(...)` object into a display name.
  /// Tolerates a missing embed, a missing profile, and blank name columns.
  static String? _ownerNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    final parts = [embedded['first_name'], embedded['last_name']]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// owner_id, church_id and family_id are deliberately absent: a database
  /// trigger stamps them from the author's profile so a client cannot log a
  /// relationship into another church or household.
  static Map<String, dynamic> toInsertJson({
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  }) =>
      {
        'name': name.trim(),
        'context': _blankToNull(context),
        'next_step': _blankToNull(nextStep),
        'visibility': visibility.wire,
      };

  static Map<String, dynamic> toUpdateJson({
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  }) =>
      {
        'name': name.trim(),
        'context': _blankToNull(context),
        'next_step': _blankToNull(nextStep),
        'visibility': visibility.wire,
      };
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

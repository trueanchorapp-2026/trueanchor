/// A row of `public.events`: a church-scoped calendar entry.
class Event {
  const Event({
    required this.id,
    required this.churchId,
    required this.title,
    required this.startsAt,
    required this.createdAt,
    this.createdBy,
    this.description,
    this.location,
    this.endsAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: json['id'] as String,
        churchId: json['church_id'] as String,
        createdBy: json['created_by'] as String?,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        location: json['location'] as String?,
        startsAt: _parseTime(json['starts_at']) ?? DateTime.now(),
        endsAt: _parseTime(json['ends_at']),
        createdAt: _parseTime(json['created_at']) ?? DateTime.now(),
      );

  final String id;
  final String churchId;
  final String? createdBy;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  /// True once the event's start is in the past relative to [now].
  bool isPast(DateTime now) => startsAt.isBefore(now);

  /// church_id and created_by are deliberately absent: a database trigger
  /// stamps them from the author's profile so a client cannot post an event
  /// into another church.
  static Map<String, dynamic> toWriteJson({
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) =>
      {
        'title': title.trim(),
        'description': _blankToNull(description),
        'location': _blankToNull(location),
        'starts_at': startsAt.toUtc().toIso8601String(),
        'ends_at': endsAt?.toUtc().toIso8601String(),
      };
}

DateTime? _parseTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

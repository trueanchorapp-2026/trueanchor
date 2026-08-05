class CommunityEvent {
  const CommunityEvent({
    required this.id,
    required this.communityId,
    required this.title,
    required this.startsAt,
    required this.createdAt,
    this.createdBy,
    this.description,
    this.location,
    this.endsAt,
  });

  factory CommunityEvent.fromJson(Map<String, dynamic> json) =>
      CommunityEvent(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        createdBy: json['created_by'] as String?,
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        location: json['location'] as String?,
        startsAt: _parseTime(json['starts_at']) ?? DateTime.now(),
        endsAt: _parseTime(json['ends_at']),
        createdAt: _parseTime(json['created_at']) ?? DateTime.now(),
      );

  final String id;
  final String communityId;
  final String? createdBy;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  bool isPast(DateTime now) => startsAt.isBefore(now);

  static Map<String, dynamic> toWriteJson({
    required String communityId,
    required String title,
    required String? description,
    required String? location,
    required DateTime startsAt,
    required DateTime? endsAt,
  }) =>
      {
        'community_id': communityId,
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

class Community {
  const Community({
    required this.id,
    required this.regionId,
    required this.name,
    required this.createdAt,
    this.city,
    this.state,
    this.createdBy,
  });

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        regionId: json['region_id'] as String,
        name: json['name'] as String,
        city: json['city'] as String?,
        state: json['state'] as String?,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String regionId;
  final String name;
  final String? city;
  final String? state;
  final String? createdBy;
  final DateTime createdAt;

  String get locationDisplay {
    final parts = [city, state].whereType<String>().where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  static Map<String, dynamic> toInsertJson({
    required String regionId,
    required String name,
    String? city,
    String? state,
  }) =>
      {
        'region_id': regionId,
        'name': name.trim(),
        'city': _blankToNull(city),
        'state': _blankToNull(state),
      };

  static Map<String, dynamic> toUpdateJson({
    required String name,
    String? city,
    String? state,
  }) =>
      {
        'name': name.trim(),
        'city': _blankToNull(city),
        'state': _blankToNull(state),
      };
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

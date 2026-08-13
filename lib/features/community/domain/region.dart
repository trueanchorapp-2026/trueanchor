class Region {
  const Region({
    required this.id,
    required this.name,
    required this.createdAt,
    this.createdBy,
  });

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        id: json['id'] as String,
        name: json['name'] as String,
        createdBy: json['created_by'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String name;
  final String? createdBy;
  final DateTime createdAt;

  static Map<String, dynamic> toInsertJson({required String name}) => {
        'name': name.trim(),
      };
}

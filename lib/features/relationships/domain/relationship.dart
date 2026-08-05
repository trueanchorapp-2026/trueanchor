class Relationship {
  const Relationship({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.context,
    this.nextStep,
  });

  factory Relationship.fromJson(Map<String, dynamic> json) {
    return Relationship(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      context: json['context'] as String?,
      nextStep: json['next_step'] as String?,
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
  final String name;
  final String? context;
  final String? nextStep;
  final DateTime createdAt;
  final DateTime updatedAt;

  static Map<String, dynamic> toInsertJson({
    required String name,
    String? context,
    String? nextStep,
  }) =>
      {
        'name': name.trim(),
        'context': _blankToNull(context),
        'next_step': _blankToNull(nextStep),
      };

  static Map<String, dynamic> toUpdateJson({
    required String name,
    String? context,
    String? nextStep,
  }) =>
      {
        'name': name.trim(),
        'context': _blankToNull(context),
        'next_step': _blankToNull(nextStep),
      };
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

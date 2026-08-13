class CommunityMembership {
  const CommunityMembership({
    required this.id,
    required this.communityId,
    required this.familyId,
    required this.joinedBy,
    required this.isAdmin,
    required this.joinedAt,
    this.familyName,
  });

  factory CommunityMembership.fromJson(Map<String, dynamic> json) =>
      CommunityMembership(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        familyId: json['family_id'] as String,
        joinedBy: json['joined_by'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        familyName: _familyNameFrom(json['family']),
        joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String communityId;
  final String familyId;
  final String joinedBy;
  final bool isAdmin;
  final String? familyName;
  final DateTime joinedAt;

  static String? _familyNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    return embedded['name'] as String?;
  }
}

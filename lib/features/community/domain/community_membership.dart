class CommunityMembership {
  const CommunityMembership({
    required this.id,
    required this.communityId,
    required this.familyId,
    required this.joinedBy,
    required this.joinedAt,
    this.adminUserId,
    this.familyName,
  });

  factory CommunityMembership.fromJson(Map<String, dynamic> json) =>
      CommunityMembership(
        id: json['id'] as String,
        communityId: json['community_id'] as String,
        familyId: json['family_id'] as String,
        joinedBy: json['joined_by'] as String,
        adminUserId: json['admin_user_id'] as String?,
        familyName: _familyNameFrom(json['family']),
        joinedAt: DateTime.tryParse(json['joined_at'] as String? ?? '')
                ?.toLocal() ??
            DateTime.now(),
      );

  final String id;
  final String communityId;
  final String familyId;
  final String joinedBy;

  /// The one adult in this family who is the community's admin, if any.
  final String? adminUserId;
  final String? familyName;
  final DateTime joinedAt;

  /// Community Admin is per person: other adults in the family are not.
  bool isAdminFor(String? userId) =>
      userId != null && adminUserId == userId;

  static String? _familyNameFrom(Object? embedded) {
    if (embedded is! Map) return null;
    return embedded['name'] as String?;
  }
}

/// An adult in a member family, as offered to a regional admin choosing a
/// community's admin.
class CommunityAdminCandidate {
  const CommunityAdminCandidate({
    required this.membershipId,
    required this.familyId,
    required this.userId,
    required this.isAdmin,
    this.familyName,
    this.firstName,
    this.lastName,
  });

  factory CommunityAdminCandidate.fromJson(Map<String, dynamic> json) =>
      CommunityAdminCandidate(
        membershipId: json['membership_id'] as String,
        familyId: json['family_id'] as String,
        userId: json['user_id'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        familyName: json['family_name'] as String?,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
      );

  final String membershipId;
  final String familyId;
  final String userId;
  final bool isAdmin;
  final String? familyName;
  final String? firstName;
  final String? lastName;

  String get displayName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);
    return parts.isEmpty ? 'Unnamed adult' : parts.join(' ');
  }
}

/// The adults of one member family, for the admin picker.
typedef CandidateFamily = ({
  String familyName,
  List<CommunityAdminCandidate> adults,
});

/// Groups [candidates] by family (first-seen order) so the picker can show
/// that each family has at most one admin.
List<CandidateFamily> groupCandidatesByFamily(
  List<CommunityAdminCandidate> candidates,
) {
  final byFamily = <String, List<CommunityAdminCandidate>>{};
  for (final c in candidates) {
    (byFamily[c.familyId] ??= []).add(c);
  }
  return [
    for (final adults in byFamily.values)
      (familyName: adults.first.familyName ?? 'Family', adults: adults),
  ];
}

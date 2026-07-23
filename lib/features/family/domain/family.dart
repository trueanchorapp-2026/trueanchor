/// A row of `public.families`.
class Family {
  const Family({
    required this.id,
    required this.churchId,
    required this.name,
    required this.joinCode,
    this.headOfHouseholdId,
  });

  factory Family.fromJson(Map<String, dynamic> json) => Family(
        id: json['id'] as String,
        churchId: json['church_id'] as String,
        name: json['name'] as String,
        joinCode: json['join_code'] as String,
        headOfHouseholdId: json['head_of_household_id'] as String?,
      );

  final String id;
  final String churchId;
  final String name;

  /// Shared by the head of household so the rest of the household can join.
  final String joinCode;
  final String? headOfHouseholdId;

  bool isHeadOfHousehold(String userId) => headOfHouseholdId == userId;
}

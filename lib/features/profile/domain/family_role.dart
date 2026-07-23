import 'user_role.dart';

/// Mirrors the `public.family_role` Postgres enum: what a household calls a
/// member, assigned by the head of household.
///
/// This is a label, not a permission level. [permissionRole] is the single
/// place the label turns into the [UserRole] that RLS actually reads, and it
/// mirrors `private.user_role_for_family_role`. Adding a new label here means
/// adding it there too — nowhere else.
///
/// [wire] must stay byte-identical to the SQL enum labels.
enum FamilyRole {
  parent('parent', 'Parent'),
  guardian('guardian', 'Guardian'),
  grandparent('grandparent', 'Grandparent'),
  youth('youth', 'Youth');

  const FamilyRole(this.wire, this.label);

  final String wire;
  final String label;

  static FamilyRole fromWire(String value) => FamilyRole.values.firstWhere(
        (role) => role.wire == value,
        orElse: () => throw ArgumentError('Unknown family_role: $value'),
      );

  static FamilyRole? tryFromWire(Object? value) =>
      value is String ? fromWire(value) : null;

  /// Every adult label carries the same permissions; only youth narrows them.
  UserRole get permissionRole =>
      this == FamilyRole.youth ? UserRole.youth : UserRole.parent;

  bool get isAdult => this != FamilyRole.youth;

  /// What the head of household may pick for a given member.
  ///
  /// The head themselves is excluded from [FamilyRole.youth]: they are the only
  /// account that can assign roles, so demoting themselves would leave the
  /// household with nobody able to undo it. The database refuses this too
  /// (`HEAD_MUST_BE_AN_ADULT`); keeping it out of the menu means the head never
  /// gets to pick an option that only fails on submit.
  static List<FamilyRole> assignableFor({required bool memberIsHead}) =>
      memberIsHead
          ? FamilyRole.values.where((role) => role.isAdult).toList()
          : FamilyRole.values;
}

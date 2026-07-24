/// Mirrors the `public.user_role` Postgres enum.
///
/// [wire] must stay byte-identical to the SQL enum labels — it is what gets
/// written to and read from the database.
enum UserRole {
  appAdmin('app_admin', 'App Admin'),
  churchAdmin('church_admin', 'Church Admin'),
  youthPastor('youth_pastor', 'Youth Pastor'),
  parent('parent', 'Parent'),
  youth('youth', 'Youth');

  const UserRole(this.wire, this.label);

  final String wire;
  final String label;

  static UserRole fromWire(String value) => UserRole.values.firstWhere(
        (role) => role.wire == value,
        orElse: () => throw ArgumentError('Unknown user_role: $value'),
      );

  /// Roles that belong to a family and must complete family setup before
  /// reaching the main app.
  bool get requiresFamily => this == UserRole.parent || this == UserRole.youth;

  /// Roles that act on behalf of the church rather than a single household.
  bool get isChurchStaff =>
      this == UserRole.churchAdmin ||
      this == UserRole.youthPastor ||
      this == UserRole.appAdmin;

  /// Who may create and manage church events. Mirrors the `events_insert`
  /// RLS policy — youth pastors and admins; everyone else is view-only.
  bool get canManageEvents => isChurchStaff;

  /// Who may record a spiritual milestone for a youth. Mirrors the
  /// `milestones_insert` RLS policy — a parent (for their own family) or
  /// church staff. A youth can view their own but never record one.
  bool get canRecordMilestone => this == UserRole.parent || isChurchStaff;
}

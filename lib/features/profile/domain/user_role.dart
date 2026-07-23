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
}

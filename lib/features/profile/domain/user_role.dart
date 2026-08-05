/// Mirrors the `public.user_role` Postgres enum.
///
/// [wire] must stay byte-identical to the SQL enum labels — it is what gets
/// written to and read from the database.
enum UserRole {
  appAdmin('app_admin', 'App Admin'),
  regionalAdmin('regional_admin', 'Regional Admin'),
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

  /// Who may author the daily devotional every church reads. Mirrors
  /// `devotionals_insert` — the platform role, not a church one. There is no
  /// in-app authoring surface yet; content arrives through the seed script.
  bool get canAuthorDevotionals => this == UserRole.appAdmin;

  /// Who keeps a daily progress record. Mirrors `progress_upsert_own`: church
  /// staff read the same devotional as everyone else but have no devotional
  /// streak of their own to track, so they see no check-off card.
  bool get tracksDailyProgress =>
      this == UserRole.parent || this == UserRole.youth;

  /// Who may hold a private thread with a youth pastor. Mirrors the branches
  /// in `open_thread()` — church_admin is deliberately absent, and app_admin
  /// reaches messages only through the audited `admin_read_thread()`.
  bool get canMessagePastor =>
      this == UserRole.parent || this == UserRole.youth;

  /// The other end of that conversation.
  bool get isMessagingStaff => this == UserRole.youthPastor;

  bool get canUseMessaging => canMessagePastor || isMessagingStaff;

  /// Who sees church-wide youth engagement. Mirrors the role test inside
  /// `youth_engagement_overview()` and the `progress_select_pastor` policy —
  /// church_admin is excluded from both, because administration is not
  /// pastoral care.
  bool get canViewEngagementDashboard =>
      this == UserRole.youthPastor || this == UserRole.appAdmin;

  bool get canTrackRelationships => this == UserRole.youth;

  bool get canCreateGroupChat => this == UserRole.youthPastor;

  bool get isRegionalAdmin => this == UserRole.regionalAdmin;

  bool get canManageRegions =>
      this == UserRole.regionalAdmin || this == UserRole.appAdmin;
}

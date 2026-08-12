import '../../features/profile/domain/user_role.dart';

/// Mirrors the `public.entry_visibility` Postgres enum.
///
/// These labels are the user's only window onto a rule enforced in Postgres.
/// If the wording here ever drifts from the RLS policies in
/// `supabase/migrations/0001_init.sql`, `0009_journal_family_sharing.sql` and
/// `0025_relationship_visibility.sql`, the app is lying about privacy — so keep
/// the two in step.
///
/// This lives in `core` rather than in a feature because more than one kind of
/// entry is shared on the same ladder: journal entries and prayers use every
/// rung, Love in Action uses the youth's three. One vocabulary, one enum, one
/// set of labels the user learns once.
///
/// [label] is written to be true no matter who authored the entry, because a
/// badge in the list is read by people other than the author.
enum EntryVisibility {
  private('private', 'Private'),
  parents('parents', 'Household adults'),
  family('family', 'Whole family'),
  parentsPastor('parents_pastor', 'Household adults + pastor'),
  familyPastor('family_pastor', 'Whole family + pastor');

  const EntryVisibility(this.wire, this.label);

  final String wire;
  final String label;

  static EntryVisibility fromWire(String value) =>
      EntryVisibility.values.firstWhere(
        (visibility) => visibility.wire == value,
        orElse: () => throw ArgumentError('Unknown entry_visibility: $value'),
      );

  /// Where an author's entries sit when they share nothing.
  ///
  /// A youth's floor is themselves. A parent's floor is the other adults in
  /// their household: two adults raising the same children disciple together,
  /// so parents are never offered `private`. The value stays in the enum
  /// because entries parents wrote before that rule existed were promised
  /// "only you can see this" — see [isLegacyPrivateFor].
  ///
  /// Church staff belong to no household and cannot author entries at all;
  /// `journal_insert_own` was narrowed to enforce that in 0006.
  static EntryVisibility defaultFor(UserRole role) => switch (role) {
        UserRole.youth => private,
        UserRole.parent => parents,
        _ => private,
      };

  /// Whether this is a parent-authored entry from before parents lost the
  /// `private` rung.
  ///
  /// The sharing checkboxes cannot express it — both unchecked means "the
  /// other adults in my household" for a parent — so saving such an entry
  /// widens it. That must be said out loud rather than done quietly.
  bool isLegacyPrivateFor(UserRole role) =>
      this == private && role == UserRole.parent;

  bool get isPrivate => this == EntryVisibility.private;

  /// Whether this option reaches anyone through the author's household.
  ///
  /// Every sharing policy matches on `family_id`, so an author with no family
  /// shares with nobody — the entry is private in all but name. The editor
  /// warns rather than silently misleading the user.
  bool get needsFamily => this != EntryVisibility.private;

  /// Whether this option depends on the church having a youth pastor. If it
  /// does not, the rung reaches exactly as far as the one below it, and the
  /// editor says so — see `public.church_has_youth_pastor()`.
  bool get needsYouthPastor =>
      this == EntryVisibility.parentsPastor ||
      this == EntryVisibility.familyPastor;
}

/// The two questions the editor actually asks the author, before they are
/// folded back into the single [EntryVisibility] the database stores.
///
/// Sharing is genuinely two independent decisions — "beyond the adults?" and
/// "my youth pastor?" — that the enum flattens into one ladder. Asking them
/// separately is what makes the choice legible to a parent who does not want
/// to reason about five ordered levels.
///
/// The one place they are *not* independent is a youth choosing their pastor
/// without their parents: `entry_visibility` has no value for it, and the
/// product would not want one. [resolve] folds that combination up to
/// [EntryVisibility.parentsPastor], and [normalizedFor] hands the UI back a
/// state that matches what would actually be saved.
class EntrySharing {
  const EntrySharing({required this.withFamily, required this.withPastor});

  /// Decomposes a stored visibility back into two checkboxes.
  ///
  /// [withFamily] is role-dependent because the same `parents` value means
  /// different things either side of the household: for a youth it is a
  /// deliberate act of sharing with the adults, for a parent it is the floor
  /// they never left.
  factory EntrySharing.from(EntryVisibility visibility, UserRole role) =>
      EntrySharing(
        withFamily: switch (role) {
          UserRole.parent => visibility == EntryVisibility.family ||
              visibility == EntryVisibility.familyPastor,
          _ => !visibility.isPrivate,
        },
        withPastor: visibility.needsYouthPastor,
      );

  /// Nothing shared — the author's floor. See [EntryVisibility.defaultFor].
  static const none = EntrySharing(withFamily: false, withPastor: false);

  /// For a youth, the adults in their family. For a parent, the youth in it.
  final bool withFamily;
  final bool withPastor;

  EntryVisibility resolve(UserRole role) => switch (role) {
        UserRole.youth => withPastor
            ? EntryVisibility.parentsPastor
            : (withFamily ? EntryVisibility.parents : EntryVisibility.private),
        UserRole.parent => withFamily
            ? (withPastor
                ? EntryVisibility.familyPastor
                : EntryVisibility.family)
            : (withPastor
                ? EntryVisibility.parentsPastor
                : EntryVisibility.parents),
        _ => EntryVisibility.private,
      };

  /// This state as the checkboxes should actually render it.
  ///
  /// Round-tripping through [resolve] is what guarantees the boxes can never
  /// show a combination the database cannot store: a youth ticking "my youth
  /// pastor" comes back with "the adults in my family" ticked too.
  EntrySharing normalizedFor(UserRole role) =>
      EntrySharing.from(resolve(role), role);

  EntrySharing copyWith({bool? withFamily, bool? withPastor}) => EntrySharing(
        withFamily: withFamily ?? this.withFamily,
        withPastor: withPastor ?? this.withPastor,
      );

  /// What the "beyond the adults" box is called for each author.
  static String familyLabelFor(UserRole role) => switch (role) {
        UserRole.parent => 'The youth in my family',
        _ => 'The adults in my family',
      };

  static String familyHintFor(UserRole role) => switch (role) {
        UserRole.parent =>
          'Your kids can read this too. Use it for something the whole '
              'family should pray over.',
        _ => 'Guardians and grandparents count as adults.',
      };

  static String pastorLabelFor(UserRole role) => switch (role) {
        UserRole.parent => 'Our youth pastor',
        _ => 'My youth pastor',
      };

  /// Says where an entry lands with nothing ticked, so "unchecked" is never
  /// left to the author's imagination.
  static String floorHintFor(UserRole role) => switch (role) {
        UserRole.parent =>
          'The other adults in your household can always read your entries. '
              'Parents disciple together, so that is where entries start.',
        _ => 'With nothing ticked, this stays private — only you can see it.',
      };

  @override
  bool operator ==(Object other) =>
      other is EntrySharing &&
      other.withFamily == withFamily &&
      other.withPastor == withPastor;

  @override
  int get hashCode => Object.hash(withFamily, withPastor);

  @override
  String toString() =>
      'EntrySharing(withFamily: $withFamily, withPastor: $withPastor)';
}

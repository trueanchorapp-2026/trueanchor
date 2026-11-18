import '../../../core/domain/entry_visibility.dart';

/// How a parent shares a Love in Action relationship: a single "my family"
/// choice rather than the youth's two checkboxes.
///
/// Unlike journal entries, a parent's floor here is [EntryVisibility.private]
/// — outward relationships are personal, so nothing is shared until the parent
/// opts in. Sharing reaches the whole family (other adults and the youth),
/// matching `relationships_select_parents` and
/// `relationships_select_youth_family` in 0027.
abstract final class ParentRelationshipSharing {
  /// A new parent-authored relationship starts private.
  static const bool defaultSharesWithFamily = false;

  static EntryVisibility resolve({required bool withFamily}) =>
      withFamily ? EntryVisibility.family : EntryVisibility.private;

  /// Decomposes a stored visibility back into the checkbox. Any family-wide
  /// rung counts as shared; anything narrower reads as private.
  static bool sharesWithFamily(EntryVisibility visibility) =>
      visibility == EntryVisibility.family ||
      visibility == EntryVisibility.familyPastor;
}

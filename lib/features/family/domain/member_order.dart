import '../../profile/domain/profile.dart';

/// How a household is presented: head of household first, then the other
/// adults, then the youth. Within each band, oldest first.
///
/// Birth date is optional and, in practice, mostly absent for adults — so
/// members with no age sort to the end of their own band rather than
/// masquerading as the youngest, and fall back to alphabetical order. The
/// comparator is total and stable: equal names are broken by id so the list
/// does not reshuffle between reads.
///
/// Kept out of the widget deliberately: this is the household's ordering rule,
/// not a layout detail, and it is unit tested as such.
List<Profile> sortHouseholdMembers(
  Iterable<Profile> members, {
  required String? headOfHouseholdId,
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  return [...members]..sort(
      (a, b) => _compare(a, b, headOfHouseholdId: headOfHouseholdId, now: now),
    );
}

/// 0 = head of household, 1 = other adults, 2 = youth.
int _band(Profile member, String? headOfHouseholdId) {
  if (headOfHouseholdId != null && member.id == headOfHouseholdId) return 0;
  return member.isHouseholdAdult ? 1 : 2;
}

int _compare(
  Profile a,
  Profile b, {
  required String? headOfHouseholdId,
  required DateTime now,
}) {
  final band = _band(a, headOfHouseholdId).compareTo(
    _band(b, headOfHouseholdId),
  );
  if (band != 0) return band;

  // ageOn() rather than the raw birth date, so what drives the order is
  // exactly what the tile displays: a missing or not-yet-reached birth date
  // shows no age, and sorts as "unknown".
  final ageA = a.ageOn(now);
  final ageB = b.ageOn(now);
  if (ageA != null && ageB != null && ageA != ageB) return ageB.compareTo(ageA);
  if (ageA == null && ageB != null) return 1;
  if (ageA != null && ageB == null) return -1;

  final first = a.firstName.toLowerCase().compareTo(b.firstName.toLowerCase());
  if (first != 0) return first;
  final last = a.lastName.toLowerCase().compareTo(b.lastName.toLowerCase());
  if (last != 0) return last;
  return a.id.compareTo(b.id);
}

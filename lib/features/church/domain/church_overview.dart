import '../../family/domain/family.dart';
import '../../profile/domain/profile.dart';
import '../../profile/domain/user_role.dart';
import 'church.dart';

/// One household, with the people in it.
class FamilySummary {
  const FamilySummary({required this.family, required this.members});

  final Family family;
  final List<Profile> members;

  Profile? get headOfHousehold {
    for (final member in members) {
      if (family.isHeadOfHousehold(member.id)) return member;
    }
    return null;
  }

  List<Profile> get parents =>
      members.where((m) => m.role == UserRole.parent).toList();

  List<Profile> get youth =>
      members.where((m) => m.role == UserRole.youth).toList();

  /// A household with no youth in it has nobody for the ministry to disciple —
  /// worth surfacing to a pastor rather than burying.
  bool get hasNoYouth => youth.isEmpty;
}

/// What a pastor or church admin sees: their church, its households, and the
/// people who have signed up but are not in a household yet.
///
/// This is assembled from three flat queries rather than a join, because the
/// RLS policies already scope each of them to the caller's church.
class ChurchOverview {
  const ChurchOverview({
    required this.church,
    required this.families,
    required this.staff,
    required this.unassigned,
  });

  factory ChurchOverview.from({
    required Church church,
    required List<Family> families,
    required List<Profile> people,
  }) {
    final byFamily = <String, List<Profile>>{};
    final staff = <Profile>[];
    final unassigned = <Profile>[];

    for (final person in people) {
      if (person.role.isChurchStaff) {
        staff.add(person);
        continue;
      }
      final familyId = person.familyId;
      if (familyId == null) {
        // A parent or youth who signed up but never finished family setup.
        unassigned.add(person);
        continue;
      }
      byFamily.putIfAbsent(familyId, () => []).add(person);
    }

    int byRoleThenName(Profile a, Profile b) {
      // Parents above youth, then alphabetical, so a household reads the way
      // people expect to see it written down.
      if (a.role != b.role) {
        return a.role == UserRole.parent ? -1 : 1;
      }
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    }

    final summaries = [
      for (final family in families)
        FamilySummary(
          family: family,
          members: (byFamily[family.id] ?? const <Profile>[]).toList()
            ..sort(byRoleThenName),
        ),
    ]..sort(
        (a, b) =>
            a.family.name.toLowerCase().compareTo(b.family.name.toLowerCase()),
      );

    int byName(Profile a, Profile b) =>
        a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());

    return ChurchOverview(
      church: church,
      families: summaries,
      staff: staff..sort(byName),
      unassigned: unassigned..sort(byName),
    );
  }

  final Church church;
  final List<FamilySummary> families;
  final List<Profile> staff;
  final List<Profile> unassigned;

  int get householdCount => families.length;

  int get parentCount =>
      families.fold(0, (total, family) => total + family.parents.length);

  int get youthCount =>
      families.fold(0, (total, family) => total + family.youth.length);

  /// Everyone with an account, whether or not they finished setup.
  int get peopleCount =>
      parentCount + youthCount + staff.length + unassigned.length;
}

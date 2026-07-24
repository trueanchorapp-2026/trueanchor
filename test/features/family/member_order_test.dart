import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/family/domain/member_order.dart';
import 'package:trueanchor/features/profile/domain/family_role.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

/// Fixed "now" so ages in these tests never drift with the wall clock.
final _today = DateTime(2026, 7, 23);

Profile _member(
  String id, {
  required FamilyRole familyRole,
  String firstName = 'Member',
  String lastName = 'Doe',
  DateTime? birthDate,
  UserRole? role,
}) =>
    Profile(
      id: id,
      churchId: 'church-1',
      familyId: 'family-1',
      role: role ?? familyRole.permissionRole,
      familyRole: familyRole,
      firstName: firstName,
      lastName: lastName,
      email: '$id@example.com',
      birthDate: birthDate,
    );

List<String> _order(
  List<Profile> members, {
  String? headOfHouseholdId = 'head',
}) =>
    sortHouseholdMembers(
      members,
      headOfHouseholdId: headOfHouseholdId,
      today: _today,
    ).map((member) => member.id).toList();

void main() {
  group('sortHouseholdMembers bands', () {
    test('puts the head first, then other adults, then youth', () {
      final youth = _member(
        'youth',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2012, 1, 1),
      );
      final parent = _member('parent', familyRole: FamilyRole.parent);
      final head = _member('head', familyRole: FamilyRole.parent);

      expect(_order([youth, parent, head]), ['head', 'parent', 'youth']);
    });

    test('treats guardians and grandparents as adults', () {
      final grandparent = _member(
        'grandparent',
        familyRole: FamilyRole.grandparent,
        firstName: 'Zeta',
      );
      final guardian = _member(
        'guardian',
        familyRole: FamilyRole.guardian,
        firstName: 'Alpha',
      );
      final youth = _member(
        'youth',
        familyRole: FamilyRole.youth,
        firstName: 'Aaron',
      );

      expect(
        _order([youth, grandparent, guardian], headOfHouseholdId: null),
        ['guardian', 'grandparent', 'youth'],
      );
    });

    test('a head who is somehow youth-labelled still leads', () {
      final head = _member('head', familyRole: FamilyRole.youth);
      final parent = _member('parent', familyRole: FamilyRole.parent);

      expect(_order([head, parent]), ['head', 'parent']);
    });

    test('falls back to the permission role when no family label is set', () {
      const youth = Profile(
        id: 'youth',
        churchId: 'church-1',
        familyId: 'family-1',
        role: UserRole.youth,
        firstName: 'Unlabelled',
        lastName: 'Youth',
        email: 'y@example.com',
      );
      final parent = _member('parent', familyRole: FamilyRole.parent);

      expect(
        _order([youth, parent], headOfHouseholdId: null),
        ['parent', 'youth'],
      );
    });
  });

  group('sortHouseholdMembers age tiebreak', () {
    test('orders siblings oldest first', () {
      final middle = _member(
        'middle',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2011, 5, 4),
      );
      final oldest = _member(
        'oldest',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2008, 2, 9),
      );
      final youngest = _member(
        'youngest',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2015, 11, 30),
      );

      expect(
        _order([middle, youngest, oldest]),
        ['oldest', 'middle', 'youngest'],
      );
    });

    test('a birthday not yet reached this year counts as the younger age', () {
      // Same birth year: 'later' has not had their 2026 birthday yet on
      // 23 July, so they are a year younger than 'earlier'.
      final earlier = _member(
        'earlier',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2010, 1, 15),
      );
      final later = _member(
        'later',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2010, 12, 15),
      );

      expect(_order([later, earlier]), ['earlier', 'later']);
    });

    test('members with no birth date sort last within their own band', () {
      final undated = _member(
        'undated',
        familyRole: FamilyRole.youth,
        firstName: 'Aaron',
      );
      final dated = _member(
        'dated',
        familyRole: FamilyRole.youth,
        firstName: 'Zoe',
        birthDate: DateTime(2014, 3, 3),
      );

      // Alphabetically Aaron leads, but a known age outranks an unknown one.
      expect(_order([undated, dated]), ['dated', 'undated']);
    });

    test('a missing age never promotes someone out of their band', () {
      final undatedAdult = _member('adult', familyRole: FamilyRole.parent);
      final datedYouth = _member(
        'youth',
        familyRole: FamilyRole.youth,
        birthDate: DateTime(2013, 6, 1),
      );

      expect(
        _order([datedYouth, undatedAdult], headOfHouseholdId: null),
        ['adult', 'youth'],
      );
    });

    test('a future birth date is treated as unknown, matching the tile', () {
      final future = _member(
        'future',
        familyRole: FamilyRole.youth,
        firstName: 'Aaron',
        birthDate: DateTime(2030, 1, 1),
      );
      final real = _member(
        'real',
        familyRole: FamilyRole.youth,
        firstName: 'Zoe',
        birthDate: DateTime(2014, 1, 1),
      );

      expect(future.ageOn(_today), isNull);
      expect(_order([future, real]), ['real', 'future']);
    });
  });

  group('sortHouseholdMembers stability', () {
    test('breaks equal ages alphabetically, then by id', () {
      final birth = DateTime(2012, 4, 4);
      final zoe = _member(
        'z',
        familyRole: FamilyRole.youth,
        firstName: 'Zoe',
        birthDate: birth,
      );
      final aaronB = _member(
        'b',
        familyRole: FamilyRole.youth,
        firstName: 'Aaron',
        birthDate: birth,
      );
      final aaronA = _member(
        'a',
        familyRole: FamilyRole.youth,
        firstName: 'Aaron',
        birthDate: birth,
      );

      expect(_order([zoe, aaronB, aaronA]), ['a', 'b', 'z']);
    });

    test('is case-insensitive on names', () {
      final lower = _member('lower', familyRole: FamilyRole.youth,
          firstName: 'aaron');
      final upper = _member('upper', familyRole: FamilyRole.youth,
          firstName: 'Beth');

      expect(_order([upper, lower]), ['lower', 'upper']);
    });

    test('does not mutate the list it was given', () {
      final youth = _member('youth', familyRole: FamilyRole.youth);
      final head = _member('head', familyRole: FamilyRole.parent);
      final input = [youth, head];

      sortHouseholdMembers(
        input,
        headOfHouseholdId: 'head',
        today: _today,
      );

      expect(input.map((member) => member.id), ['youth', 'head']);
    });

    test('handles an empty household', () {
      expect(_order(const []), isEmpty);
    });
  });
}

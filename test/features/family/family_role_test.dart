import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/profile/domain/family_role.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

Profile _person({
  required UserRole role,
  FamilyRole? familyRole,
}) =>
    Profile(
      id: 'p1',
      churchId: 'church-1',
      familyId: 'fam-1',
      role: role,
      familyRole: familyRole,
      firstName: 'Ana',
      lastName: 'Nguyen',
      email: 'ana@example.com',
    );

void main() {
  group('FamilyRole permissions', () {
    // These must mirror `private.user_role_for_family_role`. If they drift, the
    // app shows a household one thing while RLS enforces another.
    test('every adult label carries parent permissions', () {
      expect(FamilyRole.parent.permissionRole, UserRole.parent);
      expect(FamilyRole.guardian.permissionRole, UserRole.parent);
      expect(FamilyRole.grandparent.permissionRole, UserRole.parent);
    });

    test('youth is the only label that narrows permissions', () {
      expect(FamilyRole.youth.permissionRole, UserRole.youth);
      expect(
        FamilyRole.values.where((role) => !role.isAdult),
        [FamilyRole.youth],
      );
    });

    test('no label can reach a church role', () {
      for (final role in FamilyRole.values) {
        expect(role.permissionRole.isChurchStaff, isFalse,
            reason: '${role.wire} escalates to staff');
      }
    });
  });

  group('FamilyRole wire values', () {
    test('round-trips the SQL enum labels', () {
      for (final role in FamilyRole.values) {
        expect(FamilyRole.fromWire(role.wire), role);
      }
    });

    test('rejects a value the app does not know', () {
      expect(() => FamilyRole.fromWire('aunt'), throwsArgumentError);
    });

    test('tryFromWire treats a null column as no label', () {
      expect(FamilyRole.tryFromWire(null), isNull);
      expect(FamilyRole.tryFromWire('guardian'), FamilyRole.guardian);
    });
  });

  group('assignable roles', () {
    test('a member can be given any label', () {
      expect(
        FamilyRole.assignableFor(memberIsHead: false),
        FamilyRole.values,
      );
    });

    test('the head is never offered youth', () {
      // Mirrors HEAD_MUST_BE_AN_ADULT: the head is the only account that can
      // assign roles, so demoting themselves would strand the household.
      final options = FamilyRole.assignableFor(memberIsHead: true);
      expect(options, isNot(contains(FamilyRole.youth)));
      expect(options, contains(FamilyRole.parent));
      expect(options, contains(FamilyRole.grandparent));
    });
  });

  group('Profile.householdLabel', () {
    test('prefers what the household calls the member', () {
      final member =
          _person(role: UserRole.parent, familyRole: FamilyRole.grandparent);
      expect(member.householdLabel, 'Grandparent');
    });

    test('falls back to the permission role when unlabelled', () {
      // Church staff have no household label, and neither do accounts created
      // before family roles existed.
      expect(_person(role: UserRole.youthPastor).householdLabel, 'Youth Pastor');
      expect(_person(role: UserRole.parent).householdLabel, 'Parent');
    });
  });

  group('Profile parsing', () {
    test('reads family_role from the row', () {
      final profile = Profile.fromJson(const {
        'id': 'p1',
        'church_id': 'church-1',
        'family_id': 'fam-1',
        'role': 'parent',
        'family_role': 'guardian',
        'first_name': 'Ana',
        'last_name': 'Nguyen',
        'email': 'ana@example.com',
      });
      expect(profile.familyRole, FamilyRole.guardian);
    });

    test('tolerates a row with no family_role', () {
      final profile = Profile.fromJson(const {
        'id': 'p1',
        'church_id': 'church-1',
        'role': 'youth_pastor',
        'first_name': 'Sam',
        'last_name': 'Lee',
        'email': 'sam@example.com',
      });
      expect(profile.familyRole, isNull);
    });

    test('a self-edit never sends family_role — the database reverts it', () {
      final json = _person(
        role: UserRole.youth,
        familyRole: FamilyRole.youth,
      ).toUpdateJson();
      expect(json.containsKey('family_role'), isFalse);
      expect(json.containsKey('role'), isFalse);
    });

    test('copyWith carries the label through an edit', () {
      final edited = _person(
        role: UserRole.parent,
        familyRole: FamilyRole.guardian,
      ).copyWith(firstName: 'Anita');
      expect(edited.familyRole, FamilyRole.guardian);
      expect(edited.firstName, 'Anita');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

Map<String, dynamic> _row({
  String? birthDate,
  String role = 'youth',
  String? familyId,
}) =>
    {
      'id': 'user-1',
      'church_id': 'church-1',
      'family_id': familyId,
      'role': role,
      'first_name': 'Ella',
      'last_name': 'Nguyen',
      'email': 'ella@example.com',
      'birth_date': birthDate,
      'grade': 9,
      'gender': 'Female',
      'baptized': true,
      'baptized_on': '2025-04-06',
    };

void main() {
  group('Profile.fromJson', () {
    test('maps every column', () {
      final profile = Profile.fromJson(_row(birthDate: '2011-03-15'));

      expect(profile.id, 'user-1');
      expect(profile.churchId, 'church-1');
      expect(profile.role, UserRole.youth);
      expect(profile.fullName, 'Ella Nguyen');
      expect(profile.grade, 9);
      expect(profile.baptized, isTrue);
      expect(profile.baptizedOn, DateTime(2025, 4, 6));
    });

    test('tolerates null optional columns', () {
      final profile = Profile.fromJson(_row());

      expect(profile.birthDate, isNull);
      expect(profile.age, isNull);
      expect(profile.familyId, isNull);
      expect(profile.hasFamily, isFalse);
    });

    test('rejects an unknown role rather than guessing one', () {
      expect(
        () => Profile.fromJson(_row(role: 'deacon')),
        throwsArgumentError,
      );
    });
  });

  group('age', () {
    Profile withBirthDate(String date) =>
        Profile.fromJson(_row(birthDate: date));

    test('counts a birthday that has already passed this year', () {
      expect(
        withBirthDate('2011-03-15').ageOn(DateTime(2026, 7, 22)),
        15,
      );
    });

    test('does not count a birthday still to come this year', () {
      expect(
        withBirthDate('2011-11-02').ageOn(DateTime(2026, 7, 22)),
        14,
      );
    });

    test('counts the birthday itself', () {
      expect(
        withBirthDate('2011-07-22').ageOn(DateTime(2026, 7, 22)),
        15,
      );
    });

    test('is null the day before birth, not negative', () {
      expect(
        withBirthDate('2026-07-23').ageOn(DateTime(2026, 7, 22)),
        isNull,
      );
    });
  });

  group('initials', () {
    test('uses first letter of each name', () {
      expect(Profile.fromJson(_row()).initials, 'EN');
    });

    test('falls back when the name is blank', () {
      final row = _row()
        ..['first_name'] = ''
        ..['last_name'] = '';
      expect(Profile.fromJson(row).initials, '?');
    });
  });

  group('toUpdateJson', () {
    test('formats dates as bare yyyy-MM-dd for Postgres date columns', () {
      final json = Profile.fromJson(_row(birthDate: '2011-03-05')).toUpdateJson();

      expect(json['birth_date'], '2011-03-05');
      expect(json['baptized_on'], '2025-04-06');
    });

    test('never sends privileged columns the database would revert', () {
      final json = Profile.fromJson(_row()).toUpdateJson();

      expect(json.containsKey('role'), isFalse);
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
    });
  });

  group('copyWith', () {
    test('clears a date when explicitly asked', () {
      final profile = Profile.fromJson(_row(birthDate: '2011-03-15'));
      expect(profile.copyWith(clearBirthDate: true).birthDate, isNull);
    });

    test('keeps the existing value when no override is given', () {
      final profile = Profile.fromJson(_row(birthDate: '2011-03-15'));
      expect(profile.copyWith(firstName: 'Ellie').birthDate,
          profile.birthDate);
    });
  });

  group('UserRole', () {
    test('wire values match the Postgres enum labels', () {
      expect(UserRole.appAdmin.wire, 'app_admin');
      expect(UserRole.churchAdmin.wire, 'church_admin');
      expect(UserRole.youthPastor.wire, 'youth_pastor');
      expect(UserRole.parent.wire, 'parent');
      expect(UserRole.youth.wire, 'youth');
    });

    test('round-trips through fromWire', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWire(role.wire), role);
      }
    });

    test('only parents and youth belong to a household', () {
      expect(UserRole.parent.requiresFamily, isTrue);
      expect(UserRole.youth.requiresFamily, isTrue);
      expect(UserRole.youthPastor.requiresFamily, isFalse);
      expect(UserRole.churchAdmin.requiresFamily, isFalse);
      expect(UserRole.appAdmin.requiresFamily, isFalse);
    });

    test('church staff are exactly the non-household roles', () {
      expect(UserRole.churchAdmin.isChurchStaff, isTrue);
      expect(UserRole.youthPastor.isChurchStaff, isTrue);
      expect(UserRole.appAdmin.isChurchStaff, isTrue);
      expect(UserRole.parent.isChurchStaff, isFalse);
      expect(UserRole.youth.isChurchStaff, isFalse);
    });

    test('only app_admin may author the devotional every church reads', () {
      // Mirrors devotionals_insert. Devotionals are global content, so a
      // church-scoped role has no business writing them.
      expect(UserRole.appAdmin.canAuthorDevotionals, isTrue);
      expect(UserRole.churchAdmin.canAuthorDevotionals, isFalse);
      expect(UserRole.youthPastor.canAuthorDevotionals, isFalse);
      expect(UserRole.parent.canAuthorDevotionals, isFalse);
      expect(UserRole.youth.canAuthorDevotionals, isFalse);
    });

    test('only household roles keep a daily progress record', () {
      // Mirrors progress_upsert_own. Staff read the same devotional but have
      // no streak of their own, so they see no check-off card.
      expect(UserRole.youth.tracksDailyProgress, isTrue);
      expect(UserRole.parent.tracksDailyProgress, isTrue);
      expect(UserRole.youthPastor.tracksDailyProgress, isFalse);
      expect(UserRole.churchAdmin.tracksDailyProgress, isFalse);
      expect(UserRole.appAdmin.tracksDailyProgress, isFalse);
    });

    test('messaging is between a household and its youth pastor', () {
      // Mirrors the branches in open_thread(). church_admin is deliberately
      // absent: administration is not pastoral care. app_admin reaches
      // messages only through the audited admin_read_thread().
      expect(UserRole.youth.canUseMessaging, isTrue);
      expect(UserRole.parent.canUseMessaging, isTrue);
      expect(UserRole.youthPastor.canUseMessaging, isTrue);
      expect(UserRole.churchAdmin.canUseMessaging, isFalse);
      expect(UserRole.appAdmin.canUseMessaging, isFalse);
    });

    test('only a member starts a thread; only a pastor receives one', () {
      expect(UserRole.youth.canMessagePastor, isTrue);
      expect(UserRole.parent.canMessagePastor, isTrue);
      expect(UserRole.youthPastor.canMessagePastor, isFalse);
      expect(UserRole.youthPastor.isMessagingStaff, isTrue);
      expect(UserRole.parent.isMessagingStaff, isFalse);
    });

    test('only pastoral roles see church-wide engagement', () {
      // Mirrors the role test inside youth_engagement_overview().
      expect(UserRole.youthPastor.canViewEngagementDashboard, isTrue);
      expect(UserRole.appAdmin.canViewEngagementDashboard, isTrue);
      expect(UserRole.churchAdmin.canViewEngagementDashboard, isFalse);
      expect(UserRole.parent.canViewEngagementDashboard, isFalse);
      expect(UserRole.youth.canViewEngagementDashboard, isFalse);
    });
  });
}

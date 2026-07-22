import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/church/domain/church.dart';
import 'package:trueanchor/features/church/domain/church_overview.dart';
import 'package:trueanchor/features/family/domain/family.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

const _church = Church(
  id: 'church-1',
  name: 'CBCCS',
  city: 'Coral Springs',
  state: 'FL',
);

Family _family(String id, String name, {String? headId}) => Family(
      id: id,
      churchId: 'church-1',
      name: name,
      joinCode: id.toUpperCase(),
      headOfHouseholdId: headId,
    );

Profile _person(
  String id, {
  required UserRole role,
  required String firstName,
  String lastName = 'Nguyen',
  String? familyId,
}) =>
    Profile(
      id: id,
      churchId: 'church-1',
      familyId: familyId,
      role: role,
      firstName: firstName,
      lastName: lastName,
      email: '$id@example.com',
    );

ChurchInvite _invite({
  int maxUses = 10,
  int uses = 0,
  DateTime? expiresAt,
  UserRole role = UserRole.parent,
}) =>
    ChurchInvite(
      id: 'invite-1',
      churchId: 'church-1',
      code: 'TAPARENT',
      role: role,
      maxUses: maxUses,
      uses: uses,
      expiresAt: expiresAt,
    );

void main() {
  group('Church', () {
    test('joins city and state for display', () {
      expect(_church.location, 'Coral Springs, FL');
    });

    test('drops a missing half rather than leaving a dangling comma', () {
      expect(
        const Church(id: 'c', name: 'X', city: 'Coral Springs').location,
        'Coral Springs',
      );
      expect(const Church(id: 'c', name: 'X', state: 'FL').location, 'FL');
      expect(const Church(id: 'c', name: 'X').location, '');
    });

    test('treats a blank city as absent', () {
      expect(
        const Church(id: 'c', name: 'X', city: '  ', state: 'FL').location,
        'FL',
      );
    });
  });

  group('ChurchInvite usability', () {
    final now = DateTime(2026, 7, 22);

    // These rules mirror the `where` clause of validate_invite_code. If they
    // drift, staff are told a code works when signup will reject it.
    test('a fresh code is usable', () {
      expect(_invite().isUsableAt(now), isTrue);
      expect(_invite().remainingUses, 10);
      expect(_invite().statusLabelAt(now), '10 left');
    });

    test('a code at its use limit is exhausted', () {
      final invite = _invite(maxUses: 5, uses: 5);
      expect(invite.isExhausted, isTrue);
      expect(invite.isUsableAt(now), isFalse);
      expect(invite.remainingUses, 0);
      expect(invite.statusLabelAt(now), 'Used up');
    });

    test('remaining uses never goes negative', () {
      expect(_invite(maxUses: 5, uses: 9).remainingUses, 0);
    });

    test('a past expiry makes it unusable', () {
      final invite = _invite(expiresAt: DateTime(2026, 7, 21));
      expect(invite.isExpiredAt(now), isTrue);
      expect(invite.isUsableAt(now), isFalse);
      expect(invite.statusLabelAt(now), 'Expired');
    });

    test('expiry is exclusive — expiring exactly now counts as expired', () {
      expect(_invite(expiresAt: now).isExpiredAt(now), isTrue);
    });

    test('a future expiry is fine', () {
      expect(_invite(expiresAt: DateTime(2026, 8, 1)).isUsableAt(now), isTrue);
    });

    test('no expiry means it never expires', () {
      expect(_invite().isExpiredAt(DateTime(2099)), isFalse);
    });
  });

  group('invite codes', () {
    test('normalises the way the database matches: upper, no spaces', () {
      expect(ChurchInvite.normalizeCode('  ta parent '), 'TAPARENT');
      expect(ChurchInvite.normalizeCode('ta\tparent'), 'TAPARENT');
      expect(ChurchInvite.normalizeCode(''), '');
    });

    test('generates the requested length', () {
      expect(ChurchInvite.generateCode().length, 8);
      expect(ChurchInvite.generateCode(length: 6).length, 6);
    });

    test('avoids characters people confuse when reading a code aloud', () {
      final random = Random(7);
      for (var i = 0; i < 200; i++) {
        final code = ChurchInvite.generateCode(random: random);
        expect(RegExp(r'^[A-HJ-NP-Z2-9]+$').hasMatch(code), isTrue,
            reason: '$code contains an ambiguous character');
      }
    });

    test('toInsertJson normalises the code and writes the role wire value', () {
      final json = ChurchInvite(
        id: '',
        churchId: 'church-1',
        code: ' ta youth ',
        role: UserRole.youth,
        maxUses: 25,
        uses: 0,
      ).toInsertJson();

      expect(json['code'], 'TAYOUTH');
      expect(json['role'], 'youth');
      expect(json['church_id'], 'church-1');
      expect(json['max_uses'], 25);
      expect(json['expires_at'], isNull);
    });
  });

  group('ChurchOverview.from', () {
    ChurchOverview build() => ChurchOverview.from(
          church: _church,
          families: [
            _family('fam-2', 'Zimmerman', headId: 'p3'),
            _family('fam-1', 'Alvarez', headId: 'p1'),
            _family('fam-3', 'Empty'),
          ],
          people: [
            _person('p1',
                role: UserRole.parent, firstName: 'Ana', familyId: 'fam-1'),
            _person('p2',
                role: UserRole.youth, firstName: 'Beto', familyId: 'fam-1'),
            _person('p5',
                role: UserRole.youth, firstName: 'Ada', familyId: 'fam-1'),
            _person('p3',
                role: UserRole.parent, firstName: 'Zoe', familyId: 'fam-2'),
            _person('p4', role: UserRole.youthPastor, firstName: 'Pastor'),
            _person('p6', role: UserRole.parent, firstName: 'Drifting'),
          ],
        );

    test('groups people into their households', () {
      final overview = build();
      final alvarez =
          overview.families.firstWhere((f) => f.family.id == 'fam-1');

      expect(alvarez.members.map((m) => m.id), ['p1', 'p5', 'p2']);
      expect(alvarez.parents.map((m) => m.id), ['p1']);
      expect(alvarez.youth.map((m) => m.id), ['p5', 'p2']);
    });

    test('sorts households by name', () {
      expect(
        build().families.map((f) => f.family.name),
        ['Alvarez', 'Empty', 'Zimmerman'],
      );
    });

    test('lists parents before youth, then alphabetically', () {
      final alvarez =
          build().families.firstWhere((f) => f.family.id == 'fam-1');
      expect(
        alvarez.members.map((m) => '${m.role.wire}:${m.firstName}'),
        ['parent:Ana', 'youth:Ada', 'youth:Beto'],
      );
    });

    test('keeps church staff out of households', () {
      final overview = build();
      expect(overview.staff.map((p) => p.id), ['p4']);
      for (final family in overview.families) {
        expect(family.members.map((m) => m.id), isNot(contains('p4')));
      }
    });

    test('surfaces people who never finished family setup', () {
      // A parent stranded here can't be reached by any household-scoped
      // feature, so a pastor needs to see them.
      expect(build().unassigned.map((p) => p.id), ['p6']);
    });

    test('keeps a household with nobody in it, and flags it', () {
      final empty = build().families.firstWhere((f) => f.family.id == 'fam-3');
      expect(empty.members, isEmpty);
      expect(empty.hasNoYouth, isTrue);
      expect(empty.headOfHousehold, isNull);
    });

    test('flags a household with parents but no youth', () {
      final zimmerman =
          build().families.firstWhere((f) => f.family.id == 'fam-2');
      expect(zimmerman.parents, hasLength(1));
      expect(zimmerman.hasNoYouth, isTrue);
    });

    test('resolves the head of household', () {
      final alvarez =
          build().families.firstWhere((f) => f.family.id == 'fam-1');
      expect(alvarez.headOfHousehold?.id, 'p1');
    });

    test('counts everyone exactly once', () {
      final overview = build();
      expect(overview.householdCount, 3);
      expect(overview.parentCount, 2); // p1, p3 -- not the unassigned p6
      expect(overview.youthCount, 2);
      expect(overview.staff, hasLength(1));
      expect(overview.unassigned, hasLength(1));
      expect(overview.peopleCount, 6);
    });

    test('a brand new church reads as empty rather than throwing', () {
      final overview = ChurchOverview.from(
        church: _church,
        families: const [],
        people: const [],
      );
      expect(overview.householdCount, 0);
      expect(overview.peopleCount, 0);
      expect(overview.families, isEmpty);
    });

    test('ignores a family_id pointing at a family it cannot see', () {
      // RLS can return a person whose household row is filtered out. That
      // person should not silently vanish from the counts... but they also
      // must not be invented into a household that was not returned.
      final overview = ChurchOverview.from(
        church: _church,
        families: [_family('fam-1', 'Alvarez')],
        people: [
          _person('p9',
              role: UserRole.youth, firstName: 'Ghost', familyId: 'fam-99'),
        ],
      );
      expect(overview.families.single.members, isEmpty);
      expect(overview.unassigned, isEmpty);
    });
  });
}

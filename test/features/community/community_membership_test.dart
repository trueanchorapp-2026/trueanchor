import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/community_membership.dart';

CommunityAdminCandidate _candidate(
  String userId,
  String familyId, {
  String? familyName,
  bool isAdmin = false,
}) =>
    CommunityAdminCandidate(
      membershipId: 'm-$familyId',
      familyId: familyId,
      userId: userId,
      isAdmin: isAdmin,
      familyName: familyName,
      firstName: userId,
    );

void main() {
  group('CommunityMembership admin', () {
    final membership = CommunityMembership.fromJson({
      'id': 'm1',
      'community_id': 'c1',
      'family_id': 'f1',
      'joined_by': 'dad',
      'admin_user_id': 'mom',
      'family': {'name': 'Smith'},
      'joined_at': '2026-01-01T00:00:00Z',
    });

    test('reads admin_user_id and family name', () {
      expect(membership.adminUserId, 'mom');
      expect(membership.familyName, 'Smith');
    });

    test('admin is per person: a spouse in the same family is not', () {
      expect(membership.isAdminFor('mom'), isTrue);
      expect(membership.isAdminFor('dad'), isFalse);
      expect(membership.isAdminFor(null), isFalse);
    });

    test('no admin set means nobody is admin', () {
      final none = CommunityMembership.fromJson({
        'id': 'm1',
        'community_id': 'c1',
        'family_id': 'f1',
        'joined_by': 'dad',
      });
      expect(none.isAdminFor('dad'), isFalse);
    });
  });

  group('CommunityAdminCandidate', () {
    test('fromJson and displayName', () {
      final c = CommunityAdminCandidate.fromJson({
        'membership_id': 'm1',
        'family_id': 'f1',
        'user_id': 'u1',
        'is_admin': true,
        'family_name': 'Smith',
        'first_name': ' Ana ',
        'last_name': 'Smith',
      });
      expect(c.isAdmin, isTrue);
      expect(c.displayName, 'Ana Smith');
    });

    test('displayName falls back when unnamed', () {
      expect(
        const CommunityAdminCandidate(
          membershipId: 'm',
          familyId: 'f',
          userId: 'u',
          isAdmin: false,
          firstName: ' ',
        ).displayName,
        'Unnamed adult',
      );
    });

    test('groupCandidatesByFamily keeps first-seen order', () {
      final groups = groupCandidatesByFamily([
        _candidate('a', 'f2', familyName: 'Lee'),
        _candidate('b', 'f1'),
        _candidate('c', 'f2', familyName: 'Lee', isAdmin: true),
      ]);
      expect(groups.map((g) => g.familyName), ['Lee', 'Family']);
      expect(groups.first.adults.map((a) => a.userId), ['a', 'c']);
      expect(groups.last.adults.single.userId, 'b');
    });
  });
}

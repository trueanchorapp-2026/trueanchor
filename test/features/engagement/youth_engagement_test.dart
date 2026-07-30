import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/engagement/domain/youth_engagement.dart';

final _asOf = DateTime(2026, 7, 29);

YouthEngagement _youth({
  String profileId = 'youth-1',
  String firstName = 'Sam',
  String lastName = 'Rivera',
  int? daysAgo,
  int activeLastSeven = 7,
  int activeLastThirty = 30,
  int currentStreak = 7,
  int longestStreak = 7,
}) =>
    YouthEngagement(
      profileId: profileId,
      firstName: firstName,
      lastName: lastName,
      lastActiveOn:
          daysAgo == null ? null : _asOf.subtract(Duration(days: daysAgo)),
      activeLastSeven: activeLastSeven,
      activeLastThirty: activeLastThirty,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      asOf: _asOf,
    );

void main() {
  group('YouthEngagement.fromJson', () {
    test('reads the row youth_engagement_overview returns', () {
      final youth = YouthEngagement.fromJson(
        <String, dynamic>{
          'profile_id': 'youth-1',
          'first_name': 'Sam',
          'last_name': 'Rivera',
          'grade': 9,
          'last_active_on': '2026-07-27',
          'active_last_7': 4,
          'active_last_30': 18,
          'current_streak': 2,
          'longest_streak': 11,
        },
        asOf: _asOf,
      );

      expect(youth.displayName, 'Sam Rivera');
      expect(youth.grade, 9);
      expect(youth.daysSinceActive, 2);
      expect(youth.longestStreak, 11);
    });

    test('a youth who has never checked in comes back with nulls, not zeros',
        () {
      // The left join in the RPC exists precisely so this row survives; the
      // entity has to survive it too.
      final youth = YouthEngagement.fromJson(
        <String, dynamic>{
          'profile_id': 'youth-2',
          'first_name': 'Alex',
          'last_name': 'Chen',
          'grade': null,
          'last_active_on': null,
          'active_last_7': 0,
          'active_last_30': 0,
          'current_streak': 0,
          'longest_streak': 0,
        },
        asOf: _asOf,
      );

      expect(youth.lastActiveOn, isNull);
      expect(youth.daysSinceActive, isNull);
      expect(youth.status, EngagementStatus.neverStarted);
    });
  });

  group('EngagementStatus', () {
    test('two days quiet is not yet the alert', () {
      expect(_youth(daysAgo: 2).status, isNot(EngagementStatus.atRisk));
    });

    test('three days quiet is the alert CLAUDE.md asks for', () {
      expect(_youth(daysAgo: 3, activeLastSeven: 4).status,
          EngagementStatus.atRisk);
    });

    test('thirteen days is still at risk, fourteen is dormant', () {
      expect(_youth(daysAgo: 13, activeLastSeven: 0).status,
          EngagementStatus.atRisk);
      expect(_youth(daysAgo: 14, activeLastSeven: 0).status,
          EngagementStatus.dormant);
    });

    test('never started is its own status, not dormancy', () {
      // A youth who never began needs an introduction; one who stopped needs a
      // nudge. Collapsing them would hide the difference from the pastor.
      expect(_youth(daysAgo: 20, activeLastSeven: 0).status,
          EngagementStatus.dormant);
      expect(_youth(daysAgo: null).status, EngagementStatus.neverStarted);
    });

    test('turning up thinly reads as slipping, not on track', () {
      expect(_youth(daysAgo: 1, activeLastSeven: 3).status,
          EngagementStatus.slipping);
      expect(_youth(daysAgo: 1, activeLastSeven: 4).status,
          EngagementStatus.onTrack);
    });

    test('only the concerning statuses ask for attention', () {
      expect(EngagementStatus.onTrack.needsAttention, isFalse);
      expect(EngagementStatus.slipping.needsAttention, isFalse);
      expect(EngagementStatus.atRisk.needsAttention, isTrue);
      expect(EngagementStatus.dormant.needsAttention, isTrue);
      expect(EngagementStatus.neverStarted.needsAttention, isTrue);
    });

    test('is computed against the as-of date, not the wall clock', () {
      // The page can stay open past midnight; the counts beside the label came
      // from the database and must not disagree with it.
      final youth = YouthEngagement(
        profileId: 'youth-1',
        firstName: 'Sam',
        lastName: 'Rivera',
        lastActiveOn: DateTime(2020),
        activeLastSeven: 7,
        activeLastThirty: 30,
        currentStreak: 7,
        longestStreak: 7,
        asOf: DateTime(2020),
      );

      expect(youth.daysSinceActive, 0);
      expect(youth.status, EngagementStatus.onTrack);
    });
  });

  group('compareByConcern', () {
    test('ranks the quietest youth above the merely at-risk', () {
      final roster = [
        _youth(profileId: 'a', firstName: 'Ana', daysAgo: 1),
        _youth(
            profileId: 'b',
            firstName: 'Ben',
            daysAgo: 4,
            activeLastSeven: 2),
        _youth(profileId: 'c', firstName: 'Cara', daysAgo: null),
        _youth(
            profileId: 'd',
            firstName: 'Dev',
            daysAgo: 20,
            activeLastSeven: 0),
      ]..sort(YouthEngagement.compareByConcern);

      expect(
        roster.map((y) => y.profileId),
        ['c', 'd', 'b', 'a'],
      );
    });

    test('breaks a tie by how long they have been gone', () {
      final roster = [
        _youth(
            profileId: 'a',
            firstName: 'Ana',
            daysAgo: 3,
            activeLastSeven: 1),
        _youth(
            profileId: 'b',
            firstName: 'Ben',
            daysAgo: 9,
            activeLastSeven: 0),
      ]..sort(YouthEngagement.compareByConcern);

      expect(roster.first.profileId, 'b');
    });

    test('breaks a remaining tie by name, so reloads do not reshuffle', () {
      final roster = [
        _youth(profileId: 'z', firstName: 'Zoe', daysAgo: null),
        _youth(profileId: 'a', firstName: 'Ana', daysAgo: null),
      ]..sort(YouthEngagement.compareByConcern);

      expect(roster.map((y) => y.profileId), ['a', 'z']);
    });
  });

  group('displayName', () {
    test('falls back rather than showing an empty row', () {
      expect(_youth(firstName: '', lastName: '').displayName, 'Youth');
    });
  });
}

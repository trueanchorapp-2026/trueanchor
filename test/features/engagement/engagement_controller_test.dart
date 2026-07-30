import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/engagement/application/engagement_providers.dart';
import 'package:trueanchor/features/engagement/domain/engagement_repository.dart';
import 'package:trueanchor/features/engagement/domain/youth_engagement.dart';
import 'package:trueanchor/features/profile/application/profile_providers.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/profile_repository.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

class MockEngagementRepository extends Mock implements EngagementRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

final _asOf = DateTime(2026, 7, 29);

Profile _profile(UserRole role) => Profile(
      id: 'pastor-1',
      churchId: 'church-1',
      role: role,
      firstName: 'Dana',
      lastName: 'Ford',
      email: 'dana@example.com',
    );

YouthEngagement _youth({
  required String profileId,
  required String firstName,
  int? daysAgo,
  int activeLastSeven = 7,
}) =>
    YouthEngagement(
      profileId: profileId,
      firstName: firstName,
      lastName: 'Rivera',
      lastActiveOn:
          daysAgo == null ? null : _asOf.subtract(Duration(days: daysAgo)),
      activeLastSeven: activeLastSeven,
      activeLastThirty: 20,
      currentStreak: 1,
      longestStreak: 5,
      asOf: _asOf,
    );

void main() {
  late MockEngagementRepository repository;
  late MockProfileRepository profiles;

  setUp(() {
    repository = MockEngagementRepository();
    profiles = MockProfileRepository();
  });

  ProviderContainer containerWith({
    String? userId = 'pastor-1',
    UserRole role = UserRole.youthPastor,
  }) {
    when(() => profiles.fetchMine(any()))
        .thenAnswer((_) async => _profile(role));
    return ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        profileRepositoryProvider.overrideWithValue(profiles),
        engagementRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  group('EngagementOverview.build', () {
    test('loads the church roster for a youth pastor', () async {
      when(() => repository.fetchOverview(asOf: any(named: 'asOf'))).thenAnswer(
        (_) async => [_youth(profileId: 'youth-1', firstName: 'Sam')],
      );

      final container = containerWith();

      expect(
        await container.read(engagementOverviewProvider.future),
        hasLength(1),
      );
    });

    test('a church admin is never asked, because the RPC would raise', () async {
      // youth_engagement_overview() raises NOT_AUTHORIZED rather than returning
      // an empty set, so asking anyway would put an error on their screen.
      final container = containerWith(role: UserRole.churchAdmin);

      expect(await container.read(engagementOverviewProvider.future), isEmpty);
      verifyNever(() => repository.fetchOverview(asOf: any(named: 'asOf')));
    });

    test('a parent is never asked either', () async {
      final container = containerWith(role: UserRole.parent);

      expect(await container.read(engagementOverviewProvider.future), isEmpty);
      verifyNever(() => repository.fetchOverview(asOf: any(named: 'asOf')));
    });

    test('a signed-out container reads nothing', () async {
      final container = containerWith(userId: null);

      expect(await container.read(engagementOverviewProvider.future), isEmpty);
      verifyNever(() => repository.fetchOverview(asOf: any(named: 'asOf')));
    });
  });

  group('needsAttentionProvider', () {
    test('keeps only the youth a pastor should follow up', () async {
      when(() => repository.fetchOverview(asOf: any(named: 'asOf'))).thenAnswer(
        (_) async => [
          _youth(profileId: 'youth-1', firstName: 'Ana', daysAgo: null),
          _youth(
              profileId: 'youth-2',
              firstName: 'Ben',
              daysAgo: 5,
              activeLastSeven: 1),
          _youth(profileId: 'youth-3', firstName: 'Cara', daysAgo: 0),
        ],
      );

      final container = containerWith();
      await container.read(engagementOverviewProvider.future);

      expect(
        container.read(needsAttentionProvider).map((y) => y.profileId),
        ['youth-1', 'youth-2'],
      );
    });
  });

  group('youthEngagementProvider', () {
    test('finds one youth in the roster already loaded', () async {
      when(() => repository.fetchOverview(asOf: any(named: 'asOf'))).thenAnswer(
        (_) async => [_youth(profileId: 'youth-1', firstName: 'Sam')],
      );

      final container = containerWith();
      await container.read(engagementOverviewProvider.future);

      expect(
        container.read(youthEngagementProvider('youth-1'))?.displayName,
        'Sam Rivera',
      );
      expect(container.read(youthEngagementProvider('nobody')), isNull);
    });
  });
}

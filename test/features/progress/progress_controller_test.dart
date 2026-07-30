import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/devotionals/application/devotional_providers.dart';
import 'package:trueanchor/features/profile/application/profile_providers.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/profile_repository.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';
import 'package:trueanchor/features/progress/application/progress_providers.dart';
import 'package:trueanchor/features/progress/domain/daily_progress.dart';
import 'package:trueanchor/features/progress/domain/progress_repository.dart';

class MockProgressRepository extends Mock implements ProgressRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

Profile _profile(UserRole role) => Profile(
      id: 'user-1',
      churchId: 'church-1',
      familyId: 'family-1',
      role: role,
      firstName: 'Sam',
      lastName: 'Rivera',
      email: 'sam@example.com',
    );

DailyProgress _entry(
  DateTime date, {
  String id = 'progress-1',
  bool devotional = true,
  bool scripture = false,
}) =>
    DailyProgress(
      id: id,
      profileId: 'user-1',
      onDate: date,
      devotionalDone: devotional,
      scriptureDone: scripture,
    );

void main() {
  late MockProgressRepository repository;
  late MockProfileRepository profiles;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    repository = MockProgressRepository();
    profiles = MockProfileRepository();
  });

  ProviderContainer containerWith({
    String? userId = 'user-1',
    UserRole role = UserRole.youth,
  }) {
    when(() => profiles.fetchMine(any()))
        .thenAnswer((_) async => _profile(role));
    return ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        profileRepositoryProvider.overrideWithValue(profiles),
        progressRepositoryProvider.overrideWithValue(repository),
        // setToday tags the row with whatever devotional was on screen. These
        // tests are about the progress row, so stand it down rather than
        // reaching for a Supabase client that no test initialises.
        todaysDevotionalProvider.overrideWith((ref) => null),
      ],
    );
  }

  group('RecentProgress.build', () {
    test('loads the history the repository (and therefore RLS) allows',
        () async {
      final today = DateTime.now();
      when(() => repository.fetchRecent(days: any(named: 'days')))
          .thenAnswer((_) async => [_entry(today)]);

      final container = containerWith();

      expect(await container.read(recentProgressProvider.future), hasLength(1));
    });

    test('church staff keep no record, and are not asked for one', () async {
      // tracksDailyProgress mirrors progress_upsert_own. A youth pastor reads
      // the same devotional but has no streak, so the call is skipped entirely
      // rather than making a round trip that RLS would answer with nothing.
      final container = containerWith(role: UserRole.youthPastor);

      expect(await container.read(recentProgressProvider.future), isEmpty);
      verifyNever(() => repository.fetchRecent(days: any(named: 'days')));
    });

    test('a signed-out container reads nothing', () async {
      final container = containerWith(userId: null);

      expect(await container.read(recentProgressProvider.future), isEmpty);
      verifyNever(() => repository.fetchRecent(days: any(named: 'days')));
    });
  });

  group('todayProgressProvider', () {
    test('synthesises an unsaved row when the day has not been touched',
        () async {
      when(() => repository.fetchRecent(days: any(named: 'days')))
          .thenAnswer((_) async => const []);

      final container = containerWith();
      await container.read(recentProgressProvider.future);

      final today = container.read(todayProgressProvider);
      expect(today, isNotNull);
      expect(today!.isUnsaved, isTrue);
      expect(today.isOn(DateTime.now()), isTrue);
    });

    test('prefers the saved row for today over a synthesised one', () async {
      when(() => repository.fetchRecent(days: any(named: 'days'))).thenAnswer(
        (_) async => [_entry(DateTime.now(), id: 'saved-1')],
      );

      final container = containerWith();
      await container.read(recentProgressProvider.future);

      expect(container.read(todayProgressProvider)!.id, 'saved-1');
    });
  });

  group('setToday', () {
    test('replaces today\'s row without refetching the whole history',
        () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      when(() => repository.fetchRecent(days: any(named: 'days'))).thenAnswer(
        (_) async => [_entry(yesterday, id: 'older')],
      );
      when(
        () => repository.upsert(
          onDate: any(named: 'onDate'),
          devotionalDone: any(named: 'devotionalDone'),
          scriptureDone: any(named: 'scriptureDone'),
          devotionalId: any(named: 'devotionalId'),
        ),
      ).thenAnswer(
        (_) async => _entry(today, id: 'saved-1', scripture: true),
      );

      final container = containerWith();
      await container.read(recentProgressProvider.future);
      await container
          .read(recentProgressProvider.notifier)
          .setToday(devotionalDone: true, scriptureDone: true);

      final entries = container.read(recentProgressProvider).value!;
      expect(entries.map((e) => e.id), ['saved-1', 'older']);
      verify(() => repository.fetchRecent(days: any(named: 'days'))).called(1);
    });

    test('a rejected write leaves the checkboxes exactly as they were',
        () async {
      // The UI must never show a tick the database refused -- for instance the
      // date fence in progress_upsert_own rejecting a back-dated day.
      when(() => repository.fetchRecent(days: any(named: 'days')))
          .thenAnswer((_) async => const []);
      when(
        () => repository.upsert(
          onDate: any(named: 'onDate'),
          devotionalDone: any(named: 'devotionalDone'),
          scriptureDone: any(named: 'scriptureDone'),
          devotionalId: any(named: 'devotionalId'),
        ),
      ).thenThrow(const AppException('Nope'));

      final container = containerWith();
      await container.read(recentProgressProvider.future);

      await expectLater(
        container
            .read(recentProgressProvider.notifier)
            .setToday(devotionalDone: true, scriptureDone: false),
        throwsA(isA<AppException>()),
      );
      expect(container.read(todayProgressProvider)!.devotionalDone, isFalse);
    });

    test('sends the local calendar date, not a UTC one', () async {
      when(() => repository.fetchRecent(days: any(named: 'days')))
          .thenAnswer((_) async => const []);
      when(
        () => repository.upsert(
          onDate: any(named: 'onDate'),
          devotionalDone: any(named: 'devotionalDone'),
          scriptureDone: any(named: 'scriptureDone'),
          devotionalId: any(named: 'devotionalId'),
        ),
      ).thenAnswer((_) async => _entry(DateTime.now()));

      final container = containerWith();
      await container.read(recentProgressProvider.future);
      await container
          .read(recentProgressProvider.notifier)
          .setToday(devotionalDone: true, scriptureDone: false);

      final sent = verify(
        () => repository.upsert(
          onDate: captureAny(named: 'onDate'),
          devotionalDone: any(named: 'devotionalDone'),
          scriptureDone: any(named: 'scriptureDone'),
          devotionalId: any(named: 'devotionalId'),
        ),
      ).captured.single as DateTime;

      expect(sent.isUtc, isFalse);
      expect(sent.day, DateTime.now().day);
    });
  });

  group('progressStreakProvider', () {
    test('recomputes when the history changes', () async {
      final today = DateTime.now();
      when(() => repository.fetchRecent(days: any(named: 'days')))
          .thenAnswer((_) async => const []);
      when(
        () => repository.upsert(
          onDate: any(named: 'onDate'),
          devotionalDone: any(named: 'devotionalDone'),
          scriptureDone: any(named: 'scriptureDone'),
          devotionalId: any(named: 'devotionalId'),
        ),
      ).thenAnswer((_) async => _entry(today, id: 'saved-1'));

      final container = containerWith();
      await container.read(recentProgressProvider.future);
      expect(container.read(progressStreakProvider).current, 0);

      await container
          .read(recentProgressProvider.notifier)
          .setToday(devotionalDone: true, scriptureDone: false);

      expect(container.read(progressStreakProvider).current, 1);
    });
  });
}

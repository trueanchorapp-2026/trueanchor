import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/devotionals/application/devotional_providers.dart';
import 'package:trueanchor/features/devotionals/domain/devotional.dart';
import 'package:trueanchor/features/devotionals/domain/devotional_audience.dart';
import 'package:trueanchor/features/devotionals/domain/devotional_repository.dart';

class MockDevotionalRepository extends Mock implements DevotionalRepository {}

Devotional _devotional({
  String id = 'devo-1',
  DateTime? publishOn,
}) =>
    Devotional(
      id: id,
      publishOn: publishOn ?? DateTime(2026, 8, 1),
      title: 'An Anchor for the Soul',
      scriptureReference: 'Hebrews 6:19',
      scriptureText: 'We have this hope as an anchor for the soul.',
      translation: 'WEB',
      body: 'Body text.',
    );

void main() {
  late MockDevotionalRepository repository;

  setUpAll(() {
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(DevotionalAudience.youth);
  });

  setUp(() {
    repository = MockDevotionalRepository();
  });

  void stubFetch(Devotional? result) {
    when(
      () => repository.fetchForDate(
        any(),
        audience: any(named: 'audience'),
      ),
    ).thenAnswer((_) async => result);
  }

  ProviderContainer containerWith({
    String? userId = 'user-1',
    DevotionalAudience audience = DevotionalAudience.youth,
  }) =>
      ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          devotionalAudienceProvider.overrideWithValue(audience),
          devotionalRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('returns the devotional the repository resolves for today', () async {
    stubFetch(_devotional());

    final container = containerWith();

    expect(
      await container.read(todaysDevotionalProvider.future),
      isA<Devotional>().having((d) => d.id, 'id', 'devo-1'),
    );
  });

  test('surfaces an older devotional unchanged — the fallback path', () async {
    // The repository resolves the fallback, not the provider: a row dated
    // before today is a perfectly valid result and must not be filtered out.
    // The page tells the two apart with isForToday.
    stubFetch(_devotional(publishOn: DateTime(2026, 7, 28)));

    final container = containerWith();
    final devotional = await container.read(todaysDevotionalProvider.future);

    expect(devotional, isNotNull);
    expect(devotional!.isForToday(DateTime(2026, 8, 1)), isFalse);
  });

  test('returns null on an empty table rather than throwing', () async {
    stubFetch(null);

    final container = containerWith();

    expect(await container.read(todaysDevotionalProvider.future), isNull);
  });

  test('asks for the local calendar date, not a UTC one', () async {
    // A youth in California should get their own day. Any drift here shows up
    // as the wrong devotional near midnight.
    stubFetch(_devotional());

    final container = containerWith();
    await container.read(todaysDevotionalProvider.future);

    final requested = verify(
      () => repository.fetchForDate(
        captureAny(),
        audience: any(named: 'audience'),
      ),
    ).captured.single as DateTime;
    final now = DateTime.now();

    expect(requested.isUtc, isFalse);
    expect(requested.year, now.year);
    expect(requested.month, now.month);
    expect(requested.day, now.day);
  });

  test('re-reads once a user is signed in', () async {
    // Devotionals are global, but `devotionals_select` is still gated on
    // `to authenticated` — the fetch has to re-run when the session appears.
    stubFetch(_devotional());

    final container = containerWith(userId: null);
    await container.read(todaysDevotionalProvider.future);

    expect(container.read(todaysDevotionalProvider).value, isNotNull);
    verify(
      () => repository.fetchForDate(
        any(),
        audience: any(named: 'audience'),
      ),
    ).called(1);
  });

  test("passes the reader's audience through to the repository", () async {
    stubFetch(_devotional());

    final container = containerWith(audience: DevotionalAudience.adult);
    await container.read(todaysDevotionalProvider.future);

    verify(
      () => repository.fetchForDate(
        any(),
        audience: DevotionalAudience.adult,
      ),
    ).called(1);
  });
}

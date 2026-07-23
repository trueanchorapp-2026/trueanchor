import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/journal/application/journal_providers.dart';
import 'package:trueanchor/features/journal/domain/journal_entry.dart';
import 'package:trueanchor/features/journal/domain/journal_repository.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

JournalEntry _entry(
  String id, {
  EntryVisibility visibility = EntryVisibility.private,
  String authorId = 'user-1',
}) =>
    JournalEntry(
      id: id,
      authorId: authorId,
      body: 'Entry $id',
      entryType: EntryType.journal,
      visibility: visibility,
      createdAt: DateTime(2026, 7, 20),
    );

void main() {
  late MockJournalRepository repository;

  setUpAll(() {
    registerFallbackValue(EntryType.journal);
    registerFallbackValue(EntryVisibility.private);
  });

  setUp(() {
    repository = MockJournalRepository();
  });

  ProviderContainer containerWith({String? userId = 'user-1'}) =>
      ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          journalRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('build returns whatever the repository (and therefore RLS) allows',
      () async {
    // The controller must not filter: the server has already decided what this
    // user may read, and re-filtering here would only hide shared entries.
    final rows = [
      _entry('a'),
      _entry('b', visibility: EntryVisibility.parents, authorId: 'user-2'),
    ];
    when(() => repository.fetchVisible()).thenAnswer((_) async => rows);

    final container = containerWith();

    expect(await container.read(journalListProvider.future), rows);
  });

  test('add prepends the created entry so it appears without a refetch',
      () async {
    when(() => repository.fetchVisible()).thenAnswer((_) async => [_entry('a')]);
    final created = _entry('b');
    when(
      () => repository.create(
        authorId: any(named: 'authorId'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        entryType: any(named: 'entryType'),
        visibility: any(named: 'visibility'),
      ),
    ).thenAnswer((_) async => created);

    final container = containerWith();
    await container.read(journalListProvider.future);

    await container.read(journalListProvider.notifier).add(
          title: 'New',
          body: 'Body',
          entryType: EntryType.journal,
          visibility: EntryVisibility.parents,
        );

    expect(
      container.read(journalListProvider).value?.map((e) => e.id),
      ['b', 'a'],
    );
  });

  test('add passes the chosen visibility straight through, unaltered',
      () async {
    when(() => repository.fetchVisible()).thenAnswer((_) async => []);
    when(
      () => repository.create(
        authorId: any(named: 'authorId'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        entryType: any(named: 'entryType'),
        visibility: any(named: 'visibility'),
      ),
    ).thenAnswer((_) async => _entry('b'));

    final container = containerWith();
    await container.read(journalListProvider.future);

    await container.read(journalListProvider.notifier).add(
          title: null,
          body: 'Body',
          entryType: EntryType.prayer,
          visibility: EntryVisibility.parentsPastor,
        );

    final captured = verify(
      () => repository.create(
        authorId: captureAny(named: 'authorId'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        entryType: captureAny(named: 'entryType'),
        visibility: captureAny(named: 'visibility'),
      ),
    ).captured;

    expect(captured, ['user-1', EntryType.prayer, EntryVisibility.parentsPastor]);
  });

  test('add refuses when signed out instead of writing a null author',
      () async {
    when(() => repository.fetchVisible()).thenAnswer((_) async => []);

    final container = containerWith(userId: null);
    await container.read(journalListProvider.future);

    await expectLater(
      container.read(journalListProvider.notifier).add(
            title: null,
            body: 'Body',
            entryType: EntryType.journal,
            visibility: EntryVisibility.private,
          ),
      throwsA(isA<AppException>()),
    );
    verifyNever(
      () => repository.create(
        authorId: any(named: 'authorId'),
        title: any(named: 'title'),
        body: any(named: 'body'),
        entryType: any(named: 'entryType'),
        visibility: any(named: 'visibility'),
      ),
    );
  });

  test('remove drops the entry from the list', () async {
    when(() => repository.fetchVisible())
        .thenAnswer((_) async => [_entry('a'), _entry('b')]);
    when(() => repository.delete(any())).thenAnswer((_) async {});

    final container = containerWith();
    await container.read(journalListProvider.future);

    await container.read(journalListProvider.notifier).remove('a');

    expect(
      container.read(journalListProvider).value?.map((e) => e.id),
      ['b'],
    );
  });

  test('remove keeps the list intact when the delete fails', () async {
    when(() => repository.fetchVisible())
        .thenAnswer((_) async => [_entry('a'), _entry('b')]);
    when(() => repository.delete(any()))
        .thenThrow(const AppException('nope'));

    final container = containerWith();
    await container.read(journalListProvider.future);

    await expectLater(
      container.read(journalListProvider.notifier).remove('a'),
      throwsA(isA<AppException>()),
    );
    expect(container.read(journalListProvider).value?.length, 2);
  });

  test('refresh replaces the list from the repository', () async {
    var call = 0;
    when(() => repository.fetchVisible()).thenAnswer(
      (_) async => call++ == 0 ? [_entry('a')] : [_entry('a'), _entry('c')],
    );

    final container = containerWith();
    await container.read(journalListProvider.future);

    await container.read(journalListProvider.notifier).refresh();

    expect(
      container.read(journalListProvider).value?.map((e) => e.id),
      ['a', 'c'],
    );
  });

  test('refresh surfaces a failure as an error state, not a throw', () async {
    var call = 0;
    when(() => repository.fetchVisible()).thenAnswer((_) async {
      if (call++ == 0) return [_entry('a')];
      throw const AppException('offline');
    });

    final container = containerWith();
    await container.read(journalListProvider.future);

    await container.read(journalListProvider.notifier).refresh();

    expect(container.read(journalListProvider).hasError, isTrue);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/events/application/event_providers.dart';
import 'package:trueanchor/features/events/domain/event.dart';
import 'package:trueanchor/features/events/domain/event_repository.dart';

class MockEventRepository extends Mock implements EventRepository {}

Event _event(String id, {DateTime? startsAt}) => Event(
      id: id,
      churchId: 'church-1',
      title: 'Event $id',
      startsAt: startsAt ?? DateTime(2026, 8, 1),
      createdAt: DateTime(2026, 7, 20),
    );

void main() {
  late MockEventRepository repository;

  setUp(() {
    repository = MockEventRepository();
  });

  ProviderContainer containerWith({String? userId = 'user-1'}) =>
      ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          eventRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('build returns whatever the repository (and therefore RLS) allows',
      () async {
    final rows = [_event('a'), _event('b')];
    when(() => repository.fetchAll()).thenAnswer((_) async => rows);

    final container = containerWith();

    expect(await container.read(eventListProvider.future), rows);
  });

  test('add refetches so the new event lands in its sorted place', () async {
    var call = 0;
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => call++ == 0 ? [_event('a')] : [_event('a'), _event('b')],
    );
    when(
      () => repository.create(
        title: any(named: 'title'),
        description: any(named: 'description'),
        location: any(named: 'location'),
        startsAt: any(named: 'startsAt'),
        endsAt: any(named: 'endsAt'),
      ),
    ).thenAnswer((_) async => _event('b'));

    final container = containerWith();
    await container.read(eventListProvider.future);

    await container.read(eventListProvider.notifier).add(
          title: 'New',
          description: null,
          location: null,
          startsAt: DateTime(2026, 8, 2),
          endsAt: null,
        );

    expect(
      container.read(eventListProvider).value?.map((e) => e.id),
      ['a', 'b'],
    );
  });

  test('edit refetches so a re-timed event re-sorts', () async {
    var call = 0;
    when(() => repository.fetchAll()).thenAnswer(
      (_) async => call++ == 0 ? [_event('a'), _event('b')] : [_event('b')],
    );
    when(
      () => repository.update(
        id: any(named: 'id'),
        title: any(named: 'title'),
        description: any(named: 'description'),
        location: any(named: 'location'),
        startsAt: any(named: 'startsAt'),
        endsAt: any(named: 'endsAt'),
      ),
    ).thenAnswer((_) async => _event('b'));

    final container = containerWith();
    await container.read(eventListProvider.future);

    await container.read(eventListProvider.notifier).edit(
          id: 'a',
          title: 'Renamed',
          description: null,
          location: null,
          startsAt: DateTime(2026, 9, 1),
          endsAt: null,
        );

    expect(container.read(eventListProvider).value?.map((e) => e.id), ['b']);
  });

  test('remove drops the event from the list without a refetch', () async {
    when(() => repository.fetchAll())
        .thenAnswer((_) async => [_event('a'), _event('b')]);
    when(() => repository.delete(any())).thenAnswer((_) async {});

    final container = containerWith();
    await container.read(eventListProvider.future);

    await container.read(eventListProvider.notifier).remove('a');

    expect(container.read(eventListProvider).value?.map((e) => e.id), ['b']);
    // Exactly one fetch — the initial build. remove() prunes locally rather
    // than refetching.
    verify(() => repository.fetchAll()).called(1);
  });

  test('remove keeps the list intact when the delete fails', () async {
    when(() => repository.fetchAll())
        .thenAnswer((_) async => [_event('a'), _event('b')]);
    when(() => repository.delete(any())).thenThrow(const AppException('nope'));

    final container = containerWith();
    await container.read(eventListProvider.future);

    await expectLater(
      container.read(eventListProvider.notifier).remove('a'),
      throwsA(isA<AppException>()),
    );
    expect(container.read(eventListProvider).value?.length, 2);
  });
}

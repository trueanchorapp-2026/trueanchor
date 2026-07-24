import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/milestones/application/milestone_providers.dart';
import 'package:trueanchor/features/milestones/domain/milestone.dart';
import 'package:trueanchor/features/milestones/domain/milestone_repository.dart';

class MockMilestoneRepository extends Mock implements MilestoneRepository {}

Milestone _milestone(
  String id, {
  MilestoneType type = MilestoneType.baptized,
  DateTime? achievedOn,
}) =>
    Milestone(
      id: id,
      profileId: 'youth-1',
      milestoneType: type,
      achievedOn: achievedOn ?? DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 20),
    );

void main() {
  late MockMilestoneRepository repository;

  setUpAll(() {
    registerFallbackValue(MilestoneType.baptized);
  });

  setUp(() {
    repository = MockMilestoneRepository();
  });

  ProviderContainer containerWith({String? userId = 'user-1'}) =>
      ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue(userId),
          milestoneRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('build returns whatever the repository (and therefore RLS) allows',
      () async {
    final rows = [_milestone('a'), _milestone('b')];
    when(() => repository.fetchVisible()).thenAnswer((_) async => rows);

    final container = containerWith();

    expect(await container.read(milestoneListProvider.future), rows);
  });

  test('add inserts the new milestone in achieved-date order, newest first',
      () async {
    when(() => repository.fetchVisible()).thenAnswer(
      (_) async => [
        _milestone('old', achievedOn: DateTime(2026, 1, 1)),
        _milestone('older', achievedOn: DateTime(2025, 1, 1)),
      ],
    );
    final created = _milestone('new', achievedOn: DateTime(2025, 6, 1));
    when(
      () => repository.create(
        profileId: any(named: 'profileId'),
        milestoneType: any(named: 'milestoneType'),
        title: any(named: 'title'),
        note: any(named: 'note'),
        achievedOn: any(named: 'achievedOn'),
      ),
    ).thenAnswer((_) async => created);

    final container = containerWith();
    await container.read(milestoneListProvider.future);

    await container.read(milestoneListProvider.notifier).add(
          profileId: 'youth-1',
          milestoneType: MilestoneType.service,
          title: null,
          note: null,
          achievedOn: DateTime(2025, 6, 1),
        );

    // 'new' (June 2025) slots between 'old' (Jan 2026) and 'older' (Jan 2025) —
    // proving add re-sorts by achieved date rather than just prepending.
    expect(
      container.read(milestoneListProvider).value?.map((m) => m.id),
      ['old', 'new', 'older'],
    );
  });

  test('add forwards the chosen subject and type unaltered', () async {
    when(() => repository.fetchVisible()).thenAnswer((_) async => []);
    when(
      () => repository.create(
        profileId: any(named: 'profileId'),
        milestoneType: any(named: 'milestoneType'),
        title: any(named: 'title'),
        note: any(named: 'note'),
        achievedOn: any(named: 'achievedOn'),
      ),
    ).thenAnswer((_) async => _milestone('new'));

    final container = containerWith();
    await container.read(milestoneListProvider.future);

    await container.read(milestoneListProvider.notifier).add(
          profileId: 'youth-9',
          milestoneType: MilestoneType.acceptedChrist,
          title: 'Camp 2026',
          note: null,
          achievedOn: DateTime(2026, 6, 1),
        );

    final captured = verify(
      () => repository.create(
        profileId: captureAny(named: 'profileId'),
        milestoneType: captureAny(named: 'milestoneType'),
        title: any(named: 'title'),
        note: any(named: 'note'),
        achievedOn: any(named: 'achievedOn'),
      ),
    ).captured;

    expect(captured, ['youth-9', MilestoneType.acceptedChrist]);
  });

  test('remove drops the milestone from the list', () async {
    when(() => repository.fetchVisible())
        .thenAnswer((_) async => [_milestone('a'), _milestone('b')]);
    when(() => repository.delete(any())).thenAnswer((_) async {});

    final container = containerWith();
    await container.read(milestoneListProvider.future);

    await container.read(milestoneListProvider.notifier).remove('a');

    expect(
      container.read(milestoneListProvider).value?.map((m) => m.id),
      ['b'],
    );
  });

  test('remove keeps the list intact when the delete fails', () async {
    when(() => repository.fetchVisible())
        .thenAnswer((_) async => [_milestone('a'), _milestone('b')]);
    when(() => repository.delete(any())).thenThrow(const AppException('nope'));

    final container = containerWith();
    await container.read(milestoneListProvider.future);

    await expectLater(
      container.read(milestoneListProvider.notifier).remove('a'),
      throwsA(isA<AppException>()),
    );
    expect(container.read(milestoneListProvider).value?.length, 2);
  });
}

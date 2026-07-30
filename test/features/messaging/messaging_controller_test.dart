import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/error/app_exception.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/messaging/application/messaging_providers.dart';
import 'package:trueanchor/features/messaging/domain/message.dart';
import 'package:trueanchor/features/messaging/domain/message_thread.dart';
import 'package:trueanchor/features/messaging/domain/messaging_repository.dart';
import 'package:trueanchor/features/profile/application/profile_providers.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/profile_repository.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

class MockMessagingRepository extends Mock implements MessagingRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class _FakeThread extends Fake implements MessageThread {}

Profile _profile(UserRole role) => Profile(
      id: 'member-1',
      churchId: 'church-1',
      familyId: 'family-1',
      role: role,
      firstName: 'Sam',
      lastName: 'Rivera',
      email: 'sam@example.com',
    );

MessageThread _thread({
  String id = 'thread-1',
  DateTime? lastMessageAt,
  DateTime? memberReadAt,
}) =>
    MessageThread(
      id: id,
      memberId: 'member-1',
      pastorId: 'pastor-1',
      lastMessageAt: lastMessageAt ?? DateTime(2026, 7, 29, 10),
      memberLastReadAt: memberReadAt,
    );

Message _message({String id = 'message-1', DateTime? createdAt}) => Message(
      id: id,
      threadId: 'thread-1',
      senderId: 'member-1',
      body: 'Can we talk?',
      createdAt: createdAt ?? DateTime(2026, 7, 29, 10),
    );

void main() {
  late MockMessagingRepository repository;
  late MockProfileRepository profiles;

  setUpAll(() {
    registerFallbackValue(_FakeThread());
  });

  setUp(() {
    repository = MockMessagingRepository();
    profiles = MockProfileRepository();
  });

  ProviderContainer containerWith({
    String? userId = 'member-1',
    UserRole role = UserRole.youth,
  }) {
    when(() => profiles.fetchMine(any())).thenAnswer((_) async => _profile(role));
    return ProviderContainer.test(
      overrides: [
        currentUserIdProvider.overrideWithValue(userId),
        profileRepositoryProvider.overrideWithValue(profiles),
        messagingRepositoryProvider.overrideWithValue(repository),
      ],
    );
  }

  group('ThreadList.build', () {
    test('loads whatever threads_select_participant allows', () async {
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);

      final container = containerWith();

      expect(await container.read(threadListProvider.future), hasLength(1));
    });

    test('a church admin is not even asked for an inbox', () async {
      // canUseMessaging mirrors open_thread(), which raises
      // ROLE_CANNOT_MESSAGE for this role -- so skip the round trip entirely.
      final container = containerWith(role: UserRole.churchAdmin);

      expect(await container.read(threadListProvider.future), isEmpty);
      verifyNever(repository.fetchThreads);
    });

    test('a signed-out container reads nothing', () async {
      final container = containerWith(userId: null);

      expect(await container.read(threadListProvider.future), isEmpty);
      verifyNever(repository.fetchThreads);
    });
  });

  group('ThreadList.open', () {
    test('folds a newly opened thread in at the top', () async {
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);
      when(() => repository.openThread(withId: any(named: 'withId')))
          .thenAnswer((_) async => _thread(id: 'thread-2'));

      final container = containerWith();
      await container.read(threadListProvider.future);
      await container.read(threadListProvider.notifier).open();

      expect(
        container.read(threadListProvider).value!.map((t) => t.id),
        ['thread-2', 'thread-1'],
      );
    });

    test('re-opening an existing thread does not duplicate it', () async {
      // open_thread() is idempotent by (member_id, pastor_id); the list has to
      // be too, or tapping twice shows the same conversation twice.
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);
      when(() => repository.openThread(withId: any(named: 'withId')))
          .thenAnswer((_) async => _thread());

      final container = containerWith();
      await container.read(threadListProvider.future);
      await container.read(threadListProvider.notifier).open();

      expect(container.read(threadListProvider).value, hasLength(1));
    });

    test('surfaces NO_YOUTH_PASTOR as a message a youth can read', () async {
      when(repository.fetchThreads).thenAnswer((_) async => const []);
      when(() => repository.openThread(withId: any(named: 'withId')))
          .thenThrow(mapError(Exception('NO_YOUTH_PASTOR')));

      final container = containerWith();
      await container.read(threadListProvider.future);

      await expectLater(
        container.read(threadListProvider.notifier).open(),
        throwsA(
          isA<AppException>().having(
            (e) => e.message,
            'message',
            contains('has not set up a youth pastor'),
          ),
        ),
      );
    });
  });

  group('ThreadMessages.send', () {
    test('appends the sent message and bumps its thread to the top', () async {
      when(repository.fetchThreads)
          .thenAnswer((_) async => [_thread(id: 'thread-0'), _thread()]);
      when(() => repository.fetchMessages('thread-1'))
          .thenAnswer((_) async => [_message()]);
      when(
        () => repository.send(
          threadId: any(named: 'threadId'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => _message(id: 'message-2', createdAt: DateTime(2026, 8)),
      );

      final container = containerWith();
      await container.read(threadListProvider.future);
      await container.read(threadMessagesProvider('thread-1').future);
      await container
          .read(threadMessagesProvider('thread-1').notifier)
          .send('Another one');

      expect(
        container.read(threadMessagesProvider('thread-1')).value!.last.id,
        'message-2',
      );
      expect(
        container.read(threadListProvider).value!.first.id,
        'thread-1',
      );
    });

    test('a refused send adds no bubble', () async {
      // messages_insert_participant or the non-blank body check refusing must
      // not leave a message on screen that nobody else will ever receive.
      when(() => repository.fetchMessages('thread-1'))
          .thenAnswer((_) async => [_message()]);
      when(
        () => repository.send(
          threadId: any(named: 'threadId'),
          body: any(named: 'body'),
        ),
      ).thenThrow(const AppException('Nope'));

      final container = containerWith();
      await container.read(threadMessagesProvider('thread-1').future);

      await expectLater(
        container
            .read(threadMessagesProvider('thread-1').notifier)
            .send('Another one'),
        throwsA(isA<AppException>()),
      );
      expect(container.read(threadMessagesProvider('thread-1')).value,
          hasLength(1));
    });

    test('a blank body is never sent at all', () async {
      when(() => repository.fetchMessages('thread-1'))
          .thenAnswer((_) async => const []);

      final container = containerWith();
      await container.read(threadMessagesProvider('thread-1').future);
      await container
          .read(threadMessagesProvider('thread-1').notifier)
          .send('   ');

      verifyNever(
        () => repository.send(
          threadId: any(named: 'threadId'),
          body: any(named: 'body'),
        ),
      );
    });
  });

  group('ThreadMessages.remove', () {
    test('re-reads the thread rather than assuming the delete landed',
        () async {
      // A delete outside the five-minute window matches no row and reports
      // success, so the server's answer is the only trustworthy one.
      when(() => repository.deleteMessage(any())).thenAnswer((_) async {});
      when(() => repository.fetchMessages('thread-1'))
          .thenAnswer((_) async => [_message()]);

      final container = containerWith();
      await container.read(threadMessagesProvider('thread-1').future);
      await container
          .read(threadMessagesProvider('thread-1').notifier)
          .remove('message-1');

      expect(container.read(threadMessagesProvider('thread-1')).value,
          hasLength(1));
      verify(() => repository.fetchMessages('thread-1')).called(2);
    });
  });

  group('unreadThreadCountProvider', () {
    test('counts only the threads with something new for this caller',
        () async {
      when(repository.fetchThreads).thenAnswer(
        (_) async => [
          _thread(),
          _thread(
            id: 'thread-2',
            lastMessageAt: DateTime(2026, 7, 29, 10),
            memberReadAt: DateTime(2026, 7, 29, 11),
          ),
        ],
      );

      final container = containerWith();
      await container.read(threadListProvider.future);

      expect(container.read(unreadThreadCountProvider), 1);
    });
  });

  group('soloThreadProvider', () {
    test('collapses a member\'s single conversation into the tab itself',
        () async {
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);

      final container = containerWith();
      await container.read(threadListProvider.future);

      expect(container.read(soloThreadProvider)?.id, 'thread-1');
    });

    test('keeps the list when a member has two pastors, so neither is hidden',
        () async {
      when(repository.fetchThreads)
          .thenAnswer((_) async => [_thread(), _thread(id: 'thread-2')]);

      final container = containerWith();
      await container.read(threadListProvider.future);

      expect(container.read(soloThreadProvider), isNull);
    });

    test('a youth pastor always gets the list, even holding just one thread',
        () async {
      // Their inbox grows; a member's does not. Collapsing it once would put
      // them somewhere different the moment a second family writes in.
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);

      final container = containerWith(
        userId: 'pastor-1',
        role: UserRole.youthPastor,
      );
      await container.read(threadListProvider.future);

      expect(container.read(soloThreadProvider), isNull);
    });

    test('is null before the threads have loaded, so no empty thread flashes',
        () async {
      when(repository.fetchThreads).thenAnswer((_) async => [_thread()]);

      final container = containerWith();

      expect(container.read(soloThreadProvider), isNull);
    });

    test('is null when signed out', () async {
      final container = containerWith(userId: null);
      await container.read(threadListProvider.future);

      expect(container.read(soloThreadProvider), isNull);
    });
  });

  group('churchYouthPastorsProvider', () {
    test('a youth pastor is not offered a picker of their peers', () async {
      final container = containerWith(role: UserRole.youthPastor);

      expect(await container.read(churchYouthPastorsProvider.future), isEmpty);
      verifyNever(repository.fetchYouthPastors);
    });

    test('a member gets the church\'s pastors', () async {
      when(repository.fetchYouthPastors).thenAnswer(
        (_) async => const [PastorOption(id: 'pastor-1', name: 'Dana Ford')],
      );

      final container = containerWith();

      final options = await container.read(churchYouthPastorsProvider.future);
      expect(options.single.displayName, 'Dana Ford');
    });
  });
}

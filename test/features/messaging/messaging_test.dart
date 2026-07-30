import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/messaging/domain/message.dart';
import 'package:trueanchor/features/messaging/domain/message_thread.dart';
import 'package:trueanchor/features/messaging/presentation/messaging_disclosure.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

Message _message({
  String senderId = 'member-1',
  DateTime? createdAt,
}) =>
    Message(
      id: 'message-1',
      threadId: 'thread-1',
      senderId: senderId,
      body: 'Can we talk?',
      createdAt: createdAt ?? DateTime.now(),
    );

MessageThread _thread({
  DateTime? lastMessageAt,
  DateTime? memberReadAt,
  DateTime? pastorReadAt,
  String? memberName,
  String? pastorName,
}) =>
    MessageThread(
      id: 'thread-1',
      memberId: 'member-1',
      pastorId: 'pastor-1',
      lastMessageAt: lastMessageAt ?? DateTime(2026, 7, 29, 10),
      memberLastReadAt: memberReadAt,
      pastorLastReadAt: pastorReadAt,
      memberName: memberName,
      pastorName: pastorName,
    );

void main() {
  group('Message.fromJson', () {
    test('reads the row PostgREST returns', () {
      final message = Message.fromJson(<String, dynamic>{
        'id': 'message-1',
        'thread_id': 'thread-1',
        'sender_id': 'pastor-1',
        'body': 'Glad you asked.',
        'created_at': '2026-07-29T14:30:00Z',
      });

      expect(message.senderId, 'pastor-1');
      expect(message.body, 'Glad you asked.');
      // Timestamps are localised on the way in so the bubble clock matches the
      // user's own.
      expect(message.createdAt.isUtc, isFalse);
    });
  });

  group('Message.canDeleteAt', () {
    final sentAt = DateTime(2026, 7, 29, 12);

    test('offers the withdrawal just inside the five-minute window', () {
      final message = _message(createdAt: sentAt);

      expect(
        message.canDeleteAt(
          sentAt.add(const Duration(minutes: 4, seconds: 59)),
          userId: 'member-1',
        ),
        isTrue,
      );
    });

    test('withholds it once the window has closed', () {
      // Mirrors messages_delete_own_recent: after five minutes the
      // conversation is a record. Offering a button the database would refuse
      // is worse than not offering it.
      final message = _message(createdAt: sentAt);

      expect(
        message.canDeleteAt(
          sentAt.add(const Duration(minutes: 5, seconds: 1)),
          userId: 'member-1',
        ),
        isFalse,
      );
    });

    test('never offers it for someone else\'s message', () {
      final message = _message(senderId: 'pastor-1', createdAt: sentAt);

      expect(
        message.canDeleteAt(sentAt, userId: 'member-1'),
        isFalse,
      );
    });

    test('never offers it to a signed-out reader', () {
      expect(_message(createdAt: sentAt).canDeleteAt(sentAt), isFalse);
    });
  });

  group('Message.toInsertJson', () {
    test('sends only what the client owns', () {
      final json = Message.toInsertJson(
        threadId: 'thread-1',
        senderId: 'member-1',
        body: '  hello  ',
      );

      expect(json['body'], 'hello');
      // church_id is not on this table at all -- the thread carries tenancy --
      // and created_at is the database's, since the delete window is measured
      // against it.
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);
    });
  });

  group('MessageThread.isUnreadFor', () {
    test('reads the caller\'s own receipt, not the other party\'s', () {
      final thread = _thread(
        lastMessageAt: DateTime(2026, 7, 29, 10),
        memberReadAt: DateTime(2026, 7, 29, 11),
        pastorReadAt: DateTime(2026, 7, 29, 9),
      );

      expect(thread.isUnreadFor('member-1'), isFalse);
      expect(thread.isUnreadFor('pastor-1'), isTrue);
    });

    test('an untouched thread is unread', () {
      expect(_thread().isUnreadFor('member-1'), isTrue);
    });

    test('nobody is signed out and unread', () {
      expect(_thread().isUnreadFor(null), isFalse);
    });
  });

  group('MessageThread.otherPartyName', () {
    test('names the person on the other end', () {
      final thread = _thread(memberName: 'Sam Rivera', pastorName: 'Dana Ford');

      expect(thread.otherPartyName('member-1'), 'Dana Ford');
      expect(thread.otherPartyName('pastor-1'), 'Sam Rivera');
    });

    test('falls back to a role word rather than an empty inbox row', () {
      final thread = _thread();

      expect(thread.otherPartyName('member-1'), 'Youth pastor');
      expect(thread.otherPartyName('pastor-1'), 'Church member');
    });
  });

  group('MessageThread.readColumnFor', () {
    test('gives each participant the column guard_thread_columns lets them '
        'write', () {
      final thread = _thread();

      expect(thread.readColumnFor('member-1'), 'member_last_read_at');
      expect(thread.readColumnFor('pastor-1'), 'pastor_last_read_at');
    });

    test('gives an outsider nothing to write', () {
      expect(_thread().readColumnFor('stranger-1'), isNull);
      expect(_thread().readColumnFor(null), isNull);
    });
  });

  group('messagingDisclosureFor', () {
    test('never tells anyone their own role is the other party', () {
      // The single shared string this replaced told a youth pastor "only you
      // and your youth pastor can read this", and told a parent their parents
      // could not.
      expect(messagingDisclosureFor(UserRole.youthPastor),
          isNot(contains('your youth pastor')));
      expect(messagingDisclosureFor(UserRole.parent),
          isNot(contains('not your parents')));
    });

    test('tells a parent the thing they would otherwise assume wrongly', () {
      // A parent may reasonably expect to read whatever their youth writes.
      // threads_select_participant has no parent branch, so they cannot.
      expect(messagingDisclosureFor(UserRole.parent),
          contains('private to them'));
    });

    test('every wording carries the admin-access clause 0014 makes true', () {
      // Dropping this sentence for any role would make admin_read_thread()
      // undisclosed access rather than disclosed access.
      for (final role in [
        UserRole.youth,
        UserRole.parent,
        UserRole.youthPastor,
        null,
      ]) {
        expect(messagingDisclosureFor(role), contains('every access is '
            'recorded'));
        expect(messagingDisclosureFor(role), contains('church admin'));
      }
    });

    test('an unknown role gets the strongest promise, not a weaker one', () {
      // Shown while the profile is still loading; it must not over-claim, and
      // it must not read as though nobody is protected either.
      expect(messagingDisclosureFor(null), messagingDisclosureFor(UserRole.youth));
    });
  });
}

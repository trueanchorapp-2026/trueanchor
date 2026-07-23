import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/journal/domain/journal_entry.dart';

Map<String, dynamic> _row({
  String visibility = 'private',
  String entryType = 'journal',
  String? title = 'Psalm 23',
  String body = 'The Lord is my shepherd.',
}) =>
    {
      'id': 'entry-1',
      'author_id': 'user-1',
      'family_id': 'family-1',
      'title': title,
      'body': body,
      'entry_type': entryType,
      'visibility': visibility,
      'created_at': '2026-07-20T14:30:00Z',
    };

void main() {
  group('wire values match the Postgres enums', () {
    // These strings are a contract with the database. If one drifts, inserts
    // fail and — worse for `visibility` — the RLS policies stop matching.
    test('entry_type', () {
      expect(EntryType.journal.wire, 'journal');
      expect(EntryType.prayer.wire, 'prayer');
    });

    test('entry_visibility', () {
      expect(EntryVisibility.private.wire, 'private');
      expect(EntryVisibility.parents.wire, 'parents');
      expect(EntryVisibility.parentsPastor.wire, 'parents_pastor');
    });

    test('both round-trip through fromWire', () {
      for (final type in EntryType.values) {
        expect(EntryType.fromWire(type.wire), type);
      }
      for (final visibility in EntryVisibility.values) {
        expect(EntryVisibility.fromWire(visibility.wire), visibility);
      }
    });

    test('an unrecognised visibility throws rather than defaulting', () {
      // Defaulting would be dangerous: silently reading an unknown value as
      // `private` or `parents` would misreport who can see an entry.
      expect(() => EntryVisibility.fromWire('everyone'), throwsArgumentError);
      expect(() => EntryType.fromWire('note'), throwsArgumentError);
    });
  });

  group('isPrivate', () {
    test('is true only for private', () {
      expect(EntryVisibility.private.isPrivate, isTrue);
      expect(EntryVisibility.parents.isPrivate, isFalse);
      expect(EntryVisibility.parentsPastor.isPrivate, isFalse);
    });
  });

  group('JournalEntry.fromJson', () {
    test('maps a shared prayer row', () {
      final entry = JournalEntry.fromJson(
        _row(visibility: 'parents_pastor', entryType: 'prayer'),
      );

      expect(entry.id, 'entry-1');
      expect(entry.authorId, 'user-1');
      expect(entry.familyId, 'family-1');
      expect(entry.entryType, EntryType.prayer);
      expect(entry.visibility, EntryVisibility.parentsPastor);
    });

    test('converts created_at to local time', () {
      final entry = JournalEntry.fromJson(_row());
      expect(entry.createdAt.isUtc, isFalse);
      expect(
        entry.createdAt.toUtc(),
        DateTime.utc(2026, 7, 20, 14, 30),
      );
    });

    test('treats a missing body as empty rather than throwing', () {
      final row = _row()..remove('body');
      expect(JournalEntry.fromJson(row).body, '');
    });
  });

  group('displayTitle', () {
    test('prefers the title', () {
      expect(JournalEntry.fromJson(_row()).displayTitle, 'Psalm 23');
    });

    test('falls back to the first line of the body when untitled', () {
      final entry = JournalEntry.fromJson(
        _row(title: null, body: 'Grateful today.\nSecond line.'),
      );
      expect(entry.displayTitle, 'Grateful today.');
    });

    test('falls back when the title is only whitespace', () {
      final entry = JournalEntry.fromJson(_row(title: '   ', body: 'Amen.'));
      expect(entry.displayTitle, 'Amen.');
    });

    test('truncates a long first line with an ellipsis', () {
      final long = 'a' * 100;
      final entry = JournalEntry.fromJson(_row(title: null, body: long));

      expect(entry.displayTitle.length, 61); // 60 characters + the ellipsis
      expect(entry.displayTitle.endsWith('…'), isTrue);
    });

    test('leaves a 60-character line alone', () {
      final exact = 'b' * 60;
      final entry = JournalEntry.fromJson(_row(title: null, body: exact));
      expect(entry.displayTitle, exact);
    });
  });

  group('isAuthoredBy', () {
    test('matches only the author', () {
      final entry = JournalEntry.fromJson(_row());
      expect(entry.isAuthoredBy('user-1'), isTrue);
      expect(entry.isAuthoredBy('user-2'), isFalse);
    });
  });

  group('toInsertJson', () {
    Map<String, dynamic> insert({
      String? title = 'Morning',
      String body = '  Thank you, Lord.  ',
      EntryVisibility visibility = EntryVisibility.private,
    }) =>
        JournalEntry.toInsertJson(
          authorId: 'user-1',
          title: title,
          body: body,
          entryType: EntryType.journal,
          visibility: visibility,
        );

    test('never sends tenancy columns — a trigger stamps those', () {
      final json = insert();
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
    });

    test('writes the enum wire values', () {
      final json = insert(visibility: EntryVisibility.parents);
      expect(json['entry_type'], 'journal');
      expect(json['visibility'], 'parents');
    });

    test('trims the body', () {
      expect(insert()['body'], 'Thank you, Lord.');
    });

    test('normalises a blank title to null', () {
      expect(insert(title: '   ')['title'], isNull);
      expect(insert(title: null)['title'], isNull);
      expect(insert(title: '  Morning  ')['title'], 'Morning');
    });
  });
}

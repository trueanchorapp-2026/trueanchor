import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/journal/domain/journal_entry.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

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
      expect(EntryVisibility.family.wire, 'family');
      expect(EntryVisibility.parentsPastor.wire, 'parents_pastor');
      expect(EntryVisibility.familyPastor.wire, 'family_pastor');
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
      expect(EntryVisibility.family.isPrivate, isFalse);
      expect(EntryVisibility.parentsPastor.isPrivate, isFalse);
      expect(EntryVisibility.familyPastor.isPrivate, isFalse);
    });
  });

  group('needsYouthPastor', () {
    test('is true only for the rungs that name a pastor', () {
      expect(EntryVisibility.parentsPastor.needsYouthPastor, isTrue);
      expect(EntryVisibility.familyPastor.needsYouthPastor, isTrue);
      expect(EntryVisibility.private.needsYouthPastor, isFalse);
      expect(EntryVisibility.parents.needsYouthPastor, isFalse);
      expect(EntryVisibility.family.needsYouthPastor, isFalse);
    });
  });

  group('defaultFor', () {
    test('starts each role where they share nothing', () {
      expect(EntryVisibility.defaultFor(UserRole.youth),
          EntryVisibility.private);
      // A parent's floor is the other adults in their household, never
      // themselves — parents disciple together.
      expect(EntryVisibility.defaultFor(UserRole.parent),
          EntryVisibility.parents);
    });

    test('is what EntrySharing.none resolves to', () {
      // The editor renders unticked boxes and saves whatever they resolve to.
      // If these ever disagreed, a new entry would save wider than it looked.
      for (final role in [UserRole.youth, UserRole.parent]) {
        expect(EntrySharing.none.resolve(role), EntryVisibility.defaultFor(role),
            reason: '$role');
      }
    });

    test('church staff cannot author, and fall back to the narrowest', () {
      for (final role in [
        UserRole.youthPastor,
        UserRole.churchAdmin,
        UserRole.appAdmin,
      ]) {
        expect(EntryVisibility.defaultFor(role), EntryVisibility.private);
        expect(EntrySharing(withFamily: true, withPastor: true).resolve(role),
            EntryVisibility.private);
      }
    });
  });

  group('EntrySharing.resolve', () {
    test('a youth ticks their way up from private', () {
      EntryVisibility at({required bool family, required bool pastor}) =>
          EntrySharing(withFamily: family, withPastor: pastor)
              .resolve(UserRole.youth);

      expect(at(family: false, pastor: false), EntryVisibility.private);
      expect(at(family: true, pastor: false), EntryVisibility.parents);
      expect(at(family: true, pastor: true), EntryVisibility.parentsPastor);
    });

    test('a youth ticking only their pastor still includes their parents', () {
      // entry_visibility has no "pastor but not my parents" value, and the
      // product does not want one: parents are the primary disciple-makers,
      // so a pastor never becomes a channel around them.
      expect(
        const EntrySharing(withFamily: false, withPastor: true)
            .resolve(UserRole.youth),
        EntryVisibility.parentsPastor,
      );
    });

    test('a parent reaches all four combinations from their floor', () {
      EntryVisibility at({required bool family, required bool pastor}) =>
          EntrySharing(withFamily: family, withPastor: pastor)
              .resolve(UserRole.parent);

      expect(at(family: false, pastor: false), EntryVisibility.parents);
      expect(at(family: true, pastor: false), EntryVisibility.family);
      expect(at(family: false, pastor: true), EntryVisibility.parentsPastor);
      expect(at(family: true, pastor: true), EntryVisibility.familyPastor);
    });

    test('never resolves a parent to private', () {
      for (final family in [true, false]) {
        for (final pastor in [true, false]) {
          expect(
            EntrySharing(withFamily: family, withPastor: pastor)
                .resolve(UserRole.parent)
                .isPrivate,
            isFalse,
          );
        }
      }
    });

    test('anything beyond the floor is reachable through the household', () {
      // A tick that shares with nobody would be a lie in the editor.
      for (final role in [UserRole.youth, UserRole.parent]) {
        for (final family in [true, false]) {
          for (final pastor in [true, false]) {
            final resolved =
                EntrySharing(withFamily: family, withPastor: pastor)
                    .resolve(role);
            if (resolved.isPrivate) continue;
            expect(resolved.needsFamily, isTrue, reason: '$role / $resolved');
          }
        }
      }
    });
  });

  group('EntrySharing.from', () {
    test('a youth sees sharing with the adults as a tick', () {
      expect(EntrySharing.from(EntryVisibility.private, UserRole.youth),
          EntrySharing.none);
      expect(
        EntrySharing.from(EntryVisibility.parents, UserRole.youth),
        const EntrySharing(withFamily: true, withPastor: false),
      );
      expect(
        EntrySharing.from(EntryVisibility.parentsPastor, UserRole.youth),
        const EntrySharing(withFamily: true, withPastor: true),
      );
    });

    test('a parent sees the same value as their unticked floor', () {
      // `parents` is an act of sharing for a youth and the floor for a
      // parent. The same enum value must therefore split differently.
      expect(EntrySharing.from(EntryVisibility.parents, UserRole.parent),
          EntrySharing.none);
      expect(
        EntrySharing.from(EntryVisibility.family, UserRole.parent),
        const EntrySharing(withFamily: true, withPastor: false),
      );
      expect(
        EntrySharing.from(EntryVisibility.parentsPastor, UserRole.parent),
        const EntrySharing(withFamily: false, withPastor: true),
      );
      expect(
        EntrySharing.from(EntryVisibility.familyPastor, UserRole.parent),
        const EntrySharing(withFamily: true, withPastor: true),
      );
    });

    test('round-trips every value a role can actually author', () {
      // Opening an entry for editing and saving it untouched must never
      // change who can read it.
      const byRole = {
        UserRole.youth: [
          EntryVisibility.private,
          EntryVisibility.parents,
          EntryVisibility.parentsPastor,
        ],
        UserRole.parent: [
          EntryVisibility.parents,
          EntryVisibility.family,
          EntryVisibility.parentsPastor,
          EntryVisibility.familyPastor,
        ],
      };

      for (final entry in byRole.entries) {
        for (final visibility in entry.value) {
          expect(
            EntrySharing.from(visibility, entry.key).resolve(entry.key),
            visibility,
            reason: '${entry.key} / $visibility',
          );
        }
      }
    });

    test('a value outside a role\'s reach narrows rather than widens', () {
      // A youth should never hold `family`, but if one somehow did, the boxes
      // must not resolve it to something *more* visible than it already is.
      expect(
        EntrySharing.from(EntryVisibility.family, UserRole.youth)
            .resolve(UserRole.youth),
        EntryVisibility.parents,
      );
      expect(
        EntrySharing.from(EntryVisibility.familyPastor, UserRole.youth)
            .resolve(UserRole.youth),
        EntryVisibility.parentsPastor,
      );
    });
  });

  group('EntrySharing.normalizedFor', () {
    test('pulls a youth\'s family tick on when they tick their pastor', () {
      // This is what the editor stores on every tick, so the boxes can never
      // display a combination the database cannot hold.
      expect(
        const EntrySharing(withFamily: false, withPastor: true)
            .normalizedFor(UserRole.youth),
        const EntrySharing(withFamily: true, withPastor: true),
      );
    });

    test('leaves a parent\'s ticks exactly as they were', () {
      for (final family in [true, false]) {
        for (final pastor in [true, false]) {
          final sharing =
              EntrySharing(withFamily: family, withPastor: pastor);
          expect(sharing.normalizedFor(UserRole.parent), sharing);
        }
      }
    });

    test('is idempotent for every role and combination', () {
      for (final role in [UserRole.youth, UserRole.parent]) {
        for (final family in [true, false]) {
          for (final pastor in [true, false]) {
            final once = EntrySharing(withFamily: family, withPastor: pastor)
                .normalizedFor(role);
            expect(once.normalizedFor(role), once, reason: '$role');
          }
        }
      }
    });
  });

  group('isLegacyPrivateFor', () {
    test('flags only a parent-authored private entry', () {
      // Parents were once able to write `private`, and those entries were
      // promised "only you can see this". The checkboxes cannot express it,
      // so the editor has to warn before saving widens it.
      expect(EntryVisibility.private.isLegacyPrivateFor(UserRole.parent),
          isTrue);
      expect(
          EntryVisibility.private.isLegacyPrivateFor(UserRole.youth), isFalse);
      expect(EntryVisibility.parents.isLegacyPrivateFor(UserRole.parent),
          isFalse);
    });

    test('marks exactly the case where a round-trip widens an entry', () {
      // The warning and the widening must not be able to drift apart.
      for (final role in [UserRole.youth, UserRole.parent]) {
        for (final visibility in EntryVisibility.values) {
          final roundTripped =
              EntrySharing.from(visibility, role).resolve(role);
          final widens = visibility.isPrivate && !roundTripped.isPrivate;
          expect(visibility.isLegacyPrivateFor(role), widens,
              reason: '$role / $visibility');
        }
      }
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

    test('reads the embedded author name', () {
      final row = _row()
        ..['author'] = {'first_name': 'Ruth', 'last_name': 'Alvarez'};
      expect(JournalEntry.fromJson(row).authorName, 'Ruth Alvarez');
    });

    test('survives a missing, empty or partial author embed', () {
      // Inserts and updates return the bare row, and a profile RLS change
      // would drop the embed rather than fail the query. None of those may
      // break the list.
      expect(JournalEntry.fromJson(_row()).authorName, isNull);

      final empty = _row()..['author'] = <String, dynamic>{};
      expect(JournalEntry.fromJson(empty).authorName, isNull);

      final blank = _row()
        ..['author'] = {'first_name': '  ', 'last_name': null};
      expect(JournalEntry.fromJson(blank).authorName, isNull);

      final firstOnly = _row()..['author'] = {'first_name': 'Ruth'};
      expect(JournalEntry.fromJson(firstOnly).authorName, 'Ruth');
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

  group('toUpdateJson', () {
    Map<String, dynamic> update({
      String? title = 'Evening',
      String body = '  Still thankful.  ',
      EntryVisibility visibility = EntryVisibility.parents,
    }) =>
        JournalEntry.toUpdateJson(
          title: title,
          body: body,
          entryType: EntryType.prayer,
          visibility: visibility,
        );

    test('never sends ownership or tenancy columns', () {
      // An edit must not be able to reassign an entry to another author or
      // household — so the client does not even name those columns.
      final json = update();
      expect(json.containsKey('author_id'), isFalse);
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
    });

    test('carries a changed visibility, including back down to private', () {
      expect(update()['visibility'], 'parents');
      expect(update(visibility: EntryVisibility.private)['visibility'],
          'private');
    });

    test('normalises title and body exactly as an insert does', () {
      expect(update()['body'], 'Still thankful.');
      expect(update(title: '  ')['title'], isNull);
      expect(update(title: '  Evening ')['title'], 'Evening');
    });

    test('writes the entry type wire value', () {
      expect(update()['entry_type'], 'prayer');
    });
  });

  group('needsFamily', () {
    // Both sharing policies match on family_id, so an author with no household
    // shares with nobody. The editor warns on exactly this set.
    test('is false only for private', () {
      expect(EntryVisibility.private.needsFamily, isFalse);
      expect(EntryVisibility.parents.needsFamily, isTrue);
      expect(EntryVisibility.parentsPastor.needsFamily, isTrue);
    });
  });
}

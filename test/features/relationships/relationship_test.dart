import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/domain/entry_visibility.dart';
import 'package:trueanchor/features/relationships/domain/relationship.dart';

Map<String, dynamic> _row({
  String visibility = 'parents_pastor',
  Object? owner,
}) =>
    {
      'id': 'rel-1',
      'owner_id': 'youth-1',
      'name': 'Jordan',
      'context': 'School',
      'next_step': 'Invite to youth group',
      'visibility': visibility,
      'created_at': '2026-08-01T12:00:00Z',
      'updated_at': '2026-08-02T12:00:00Z',
      // Absent entirely, not null: mirrors a select that never embedded it.
      'owner': ?owner,
    };

void main() {
  group('Relationship.fromJson', () {
    test('reads each youth-reachable visibility rung', () {
      for (final rung in [
        EntryVisibility.private,
        EntryVisibility.parents,
        EntryVisibility.parentsPastor,
      ]) {
        expect(
          Relationship.fromJson(_row(visibility: rung.wire)).visibility,
          rung,
        );
      }
    });

    test('leaves ownerName null when the query did not embed the owner', () {
      expect(Relationship.fromJson(_row()).ownerName, isNull);
    });

    test('flattens the embedded owner into a display name', () {
      final relationship = Relationship.fromJson(
        _row(owner: {'first_name': 'Sam', 'last_name': 'Rivera'}),
      );
      expect(relationship.ownerName, 'Sam Rivera');
    });

    test('tolerates a half-filled or blank owner embed', () {
      expect(
        Relationship.fromJson(_row(owner: {'first_name': 'Sam'})).ownerName,
        'Sam',
      );
      expect(
        Relationship.fromJson(
          _row(owner: {'first_name': '  ', 'last_name': ''}),
        ).ownerName,
        isNull,
      );
    });
  });

  group('isOwnedBy', () {
    final relationship = Relationship.fromJson(_row());

    test('is true only for the owning profile', () {
      expect(relationship.isOwnedBy('youth-1'), isTrue);
      expect(relationship.isOwnedBy('parent-1'), isFalse);
    });

    test('is false while the user id is still unknown', () {
      // A signed-out or still-loading session must not be handed the edit and
      // delete affordances by default.
      expect(relationship.isOwnedBy(null), isFalse);
    });
  });

  group('write payloads', () {
    test('carry the wire visibility value', () {
      expect(
        Relationship.toInsertJson(
          name: 'Jordan',
          visibility: EntryVisibility.parents,
        )['visibility'],
        'parents',
      );
      expect(
        Relationship.toUpdateJson(
          name: 'Jordan',
          visibility: EntryVisibility.private,
        )['visibility'],
        'private',
      );
    });

    test('trim the name and blank optional fields to null', () {
      final json = Relationship.toInsertJson(
        name: '  Jordan  ',
        visibility: EntryVisibility.parentsPastor,
        context: '   ',
        nextStep: '  Invite to youth group ',
      );
      expect(json['name'], 'Jordan');
      expect(json['context'], isNull);
      expect(json['next_step'], 'Invite to youth group');
    });

    test('omit owner, church and family — the trigger stamps those', () {
      final json = Relationship.toInsertJson(
        name: 'Jordan',
        visibility: EntryVisibility.parentsPastor,
      );
      expect(json.containsKey('owner_id'), isFalse);
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
    });
  });
}

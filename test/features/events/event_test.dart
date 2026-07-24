import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/events/domain/event.dart';

Map<String, dynamic> _row({
  String? title = 'Youth Night',
  String? description = 'Games and a devotional.',
  String? location = 'Fellowship Hall',
  String startsAt = '2026-08-01T23:00:00Z',
  String? endsAt = '2026-08-02T01:00:00Z',
}) =>
    {
      'id': 'event-1',
      'church_id': 'church-1',
      'created_by': 'user-1',
      'title': title,
      'description': description,
      'location': location,
      'starts_at': startsAt,
      'ends_at': endsAt,
      'created_at': '2026-07-20T14:30:00Z',
    };

void main() {
  group('Event.fromJson', () {
    test('maps every column', () {
      final event = Event.fromJson(_row());

      expect(event.id, 'event-1');
      expect(event.churchId, 'church-1');
      expect(event.createdBy, 'user-1');
      expect(event.title, 'Youth Night');
      expect(event.description, 'Games and a devotional.');
      expect(event.location, 'Fellowship Hall');
    });

    test('converts timestamps to local time', () {
      final event = Event.fromJson(_row());
      expect(event.startsAt.isUtc, isFalse);
      expect(event.startsAt.toUtc(), DateTime.utc(2026, 8, 1, 23));
      expect(event.endsAt?.toUtc(), DateTime.utc(2026, 8, 2, 1));
    });

    test('leaves an absent end time null', () {
      final event = Event.fromJson(_row(endsAt: null));
      expect(event.endsAt, isNull);
    });

    test('treats a missing title as empty rather than throwing', () {
      final event = Event.fromJson(_row(title: null));
      expect(event.title, '');
    });
  });

  group('isPast', () {
    test('is true only once the start has passed', () {
      final event = Event.fromJson(_row(startsAt: '2026-08-01T23:00:00Z'));
      expect(event.isPast(DateTime.utc(2026, 8, 1, 22, 59)), isFalse);
      expect(event.isPast(DateTime.utc(2026, 8, 1, 23, 1)), isTrue);
    });
  });

  group('toWriteJson', () {
    Map<String, dynamic> write({
      String title = '  Youth Night  ',
      String? description = '  Games.  ',
      String? location = '   ',
      DateTime? endsAt,
    }) =>
        Event.toWriteJson(
          title: title,
          description: description,
          location: location,
          startsAt: DateTime.utc(2026, 8, 1, 23),
          endsAt: endsAt,
        );

    test('never sends tenancy columns — a trigger stamps those', () {
      final json = write();
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('created_by'), isFalse);
    });

    test('trims the title and blanks collapse to null', () {
      final json = write();
      expect(json['title'], 'Youth Night');
      expect(json['description'], 'Games.');
      expect(json['location'], isNull);
    });

    test('serialises the start as UTC ISO-8601', () {
      final json = write();
      expect(json['starts_at'], '2026-08-01T23:00:00.000Z');
    });

    test('omits a null end time as null', () {
      expect(write(endsAt: null)['ends_at'], isNull);
      expect(
        write(endsAt: DateTime.utc(2026, 8, 2, 1))['ends_at'],
        '2026-08-02T01:00:00.000Z',
      );
    });
  });
}

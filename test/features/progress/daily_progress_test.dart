import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/progress/domain/daily_progress.dart';

Map<String, dynamic> _json({
  String onDate = '2026-08-15',
  bool devotionalDone = true,
  bool scriptureDone = false,
  Object? devotionalId = 'devo-1',
}) =>
    {
      'id': 'progress-1',
      'profile_id': 'youth-1',
      'devotional_id': devotionalId,
      'on_date': onDate,
      'devotional_done': devotionalDone,
      'scripture_done': scriptureDone,
    };

void main() {
  group('DailyProgress.fromJson', () {
    test('on_date parses as a bare calendar date with no timezone drift', () {
      final entry = DailyProgress.fromJson(_json(onDate: '2026-08-15'));

      expect(entry.onDate.year, 2026);
      expect(entry.onDate.month, 8);
      expect(entry.onDate.day, 15);
    });

    test('a day with no published devotional still reads back', () {
      // devotional_id is nullable: Scripture reading counts on a day the
      // content calendar has a hole in it.
      final entry = DailyProgress.fromJson(_json(devotionalId: null));

      expect(entry.devotionalId, isNull);
      expect(entry.devotionalDone, isTrue);
    });
  });

  group('engagement', () {
    test('either box on its own counts as engaged', () {
      // Mirrors `devotional_done or scripture_done` in
      // private.progress_streak().
      expect(
        DailyProgress.fromJson(
          _json(devotionalDone: true, scriptureDone: false),
        ).engaged,
        isTrue,
      );
      expect(
        DailyProgress.fromJson(
          _json(devotionalDone: false, scriptureDone: true),
        ).engaged,
        isTrue,
      );
    });

    test('neither box is not engaged, and both is complete', () {
      expect(
        DailyProgress.fromJson(
          _json(devotionalDone: false, scriptureDone: false),
        ).engaged,
        isFalse,
      );
      expect(
        DailyProgress.fromJson(
          _json(devotionalDone: true, scriptureDone: true),
        ).complete,
        isTrue,
      );
    });
  });

  group('DailyProgress.empty', () {
    test('is unsaved and unchecked', () {
      final entry = DailyProgress.empty(
        profileId: 'youth-1',
        onDate: DateTime(2026, 8, 15, 21, 30),
      );

      expect(entry.isUnsaved, isTrue);
      expect(entry.engaged, isFalse);
      expect(entry.onDate, DateTime(2026, 8, 15));
    });

    test('a row read back from the database is not unsaved', () {
      expect(DailyProgress.fromJson(_json()).isUnsaved, isFalse);
    });
  });

  group('isOn', () {
    test('ignores the time of day it is compared against', () {
      final entry = DailyProgress.fromJson(_json(onDate: '2026-08-15'));

      expect(entry.isOn(DateTime(2026, 8, 15, 23, 59)), isTrue);
      expect(entry.isOn(DateTime(2026, 8, 16)), isFalse);
    });
  });

  group('toUpsertJson', () {
    test('omits the columns the trigger stamps', () {
      // trg_stamp_progress sets profile_id, church_id and family_id from the
      // caller's own profile. Sending them would be a client claiming tenancy.
      final json = DailyProgress.toUpsertJson(
        onDate: DateTime(2026, 8, 15),
        devotionalDone: true,
        scriptureDone: false,
        devotionalId: 'devo-1',
      );

      expect(json.containsKey('profile_id'), isFalse);
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
    });

    test('formats on_date as the bare yyyy-MM-dd a Postgres date wants', () {
      final json = DailyProgress.toUpsertJson(
        onDate: DateTime(2026, 8, 5, 14, 3),
        devotionalDone: false,
        scriptureDone: true,
      );

      expect(json['on_date'], '2026-08-05');
      expect(json['scripture_done'], isTrue);
      expect(json['devotional_id'], isNull);
    });
  });
}

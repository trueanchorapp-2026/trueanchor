import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/progress/domain/daily_progress.dart';
import 'package:trueanchor/features/progress/domain/progress_streak.dart';

DailyProgress _day(
  DateTime date, {
  bool devotional = true,
  bool scripture = false,
}) =>
    DailyProgress(
      id: 'p-${date.toIso8601String()}',
      profileId: 'youth-1',
      onDate: date,
      devotionalDone: devotional,
      scriptureDone: scripture,
    );

final _today = DateTime(2026, 8, 15);

void main() {
  group('ProgressStreak.from', () {
    test('an empty history is all zeros and a full week missed', () {
      final streak = ProgressStreak.from(const [], asOf: _today);

      expect(streak.current, 0);
      expect(streak.longest, 0);
      expect(streak.missedLastSeven, 7);
      expect(streak.engagedToday, isFalse);
    });

    test('engaging today starts a streak of one', () {
      final streak = ProgressStreak.from([_day(_today)], asOf: _today);

      expect(streak.current, 1);
      expect(streak.engagedToday, isTrue);
    });

    test('a streak survives a day you have not opened the app yet', () {
      // The grace rule. Someone who read yesterday and has not got to today's
      // reading by lunchtime must not be told their streak is gone.
      final streak = ProgressStreak.from(
        [_day(DateTime(2026, 8, 13)), _day(DateTime(2026, 8, 14))],
        asOf: _today,
      );

      expect(streak.current, 2);
      expect(streak.engagedToday, isFalse);
    });

    test('a two-day gap breaks the current streak but not the longest', () {
      final streak = ProgressStreak.from(
        [
          _day(DateTime(2026, 8, 8)),
          _day(DateTime(2026, 8, 9)),
          _day(DateTime(2026, 8, 10)),
        ],
        asOf: _today,
      );

      expect(streak.current, 0);
      expect(streak.longest, 3);
    });

    test('a devotional-only day and a Scripture-only day both count', () {
      // Mirrors the `devotional_done or scripture_done` test in
      // private.progress_streak(). Requiring both would punish the youth who
      // read their Bible and skipped the questions.
      final streak = ProgressStreak.from(
        [
          _day(DateTime(2026, 8, 14), devotional: true, scripture: false),
          _day(_today, devotional: false, scripture: true),
        ],
        asOf: _today,
      );

      expect(streak.current, 2);
    });

    test('a saved row with neither box checked does not count as engagement', () {
      final streak = ProgressStreak.from(
        [_day(_today, devotional: false, scripture: false)],
        asOf: _today,
      );

      expect(streak.current, 0);
      expect(streak.engagedToday, isFalse);
      expect(streak.missedLastSeven, 7);
    });

    test('missedLastSeven counts unengaged days, not absent rows', () {
      final streak = ProgressStreak.from(
        [
          _day(_today),
          _day(DateTime(2026, 8, 14)),
          _day(DateTime(2026, 8, 13)),
        ],
        asOf: _today,
      );

      expect(streak.missedLastSeven, 4);
    });

    test('days outside the last seven do not improve missedLastSeven', () {
      final streak = ProgressStreak.from(
        [_day(DateTime(2026, 8, 1)), _day(DateTime(2026, 8, 2))],
        asOf: _today,
      );

      expect(streak.missedLastSeven, 7);
      expect(streak.longest, 2);
    });

    test('a run crossing a month boundary stays one run', () {
      final streak = ProgressStreak.from(
        [
          _day(DateTime(2026, 7, 30)),
          _day(DateTime(2026, 7, 31)),
          _day(DateTime(2026, 8, 1)),
          _day(DateTime(2026, 8, 2)),
        ],
        asOf: DateTime(2026, 8, 2),
      );

      expect(streak.longest, 4);
      expect(streak.current, 4);
    });

    test('duplicate rows for one date do not inflate the streak', () {
      final streak = ProgressStreak.from(
        [_day(_today), _day(_today)],
        asOf: _today,
      );

      expect(streak.current, 1);
      expect(streak.longest, 1);
    });

    test('a future-dated row is ignored rather than extending the streak', () {
      // The +/- 1 day WITH CHECK in progress_upsert_own lets tomorrow through
      // for timezone reasons, so the calculation has to tolerate seeing it.
      final streak = ProgressStreak.from(
        [_day(DateTime(2026, 8, 16)), _day(_today)],
        asOf: _today,
      );

      expect(streak.current, 1);
      expect(streak.longest, 1);
    });

    test('unsorted input is grouped correctly', () {
      final streak = ProgressStreak.from(
        [
          _day(DateTime(2026, 8, 14)),
          _day(DateTime(2026, 8, 12)),
          _day(_today),
          _day(DateTime(2026, 8, 13)),
        ],
        asOf: _today,
      );

      expect(streak.current, 4);
    });
  });

  group('isAtRisk', () {
    test('is false at two missed days and true at three', () {
      // The threshold behind the pastor's "missed 3+ days" alert.
      final twoMissed = ProgressStreak.from(
        [
          for (var i = 0; i < 5; i++) _day(_today.subtract(Duration(days: i))),
        ],
        asOf: _today,
      );
      final threeMissed = ProgressStreak.from(
        [
          for (var i = 0; i < 4; i++) _day(_today.subtract(Duration(days: i))),
        ],
        asOf: _today,
      );

      expect(twoMissed.missedLastSeven, 2);
      expect(twoMissed.isAtRisk, isFalse);
      expect(threeMissed.missedLastSeven, 3);
      expect(threeMissed.isAtRisk, isTrue);
    });
  });

  group('headline', () {
    test('names the streak once it is more than a day old', () {
      final streak = ProgressStreak.from(
        [_day(DateTime(2026, 8, 14)), _day(_today)],
        asOf: _today,
      );

      expect(streak.headline, '2-day streak');
    });

    test('a first day reads as a beginning, not a one', () {
      expect(
        ProgressStreak.from([_day(_today)], asOf: _today).headline,
        'Streak started today',
      );
    });

    test('a broken streak reports what there is to build on', () {
      // Deliberately not "0-day streak": the card should not scold.
      final streak = ProgressStreak.from(
        [_day(DateTime(2026, 8, 1)), _day(DateTime(2026, 8, 2))],
        asOf: _today,
      );

      expect(streak.headline, 'Longest streak: 2 days');
    });

    test('invites a start when there is no history at all', () {
      expect(
        ProgressStreak.from(const [], asOf: _today).headline,
        'Check in to start a streak',
      );
    });
  });
}

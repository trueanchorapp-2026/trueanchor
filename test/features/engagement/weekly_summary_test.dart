import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/engagement/domain/weekly_summary.dart';

void main() {
  group('WeeklySummary.fromJson', () {
    test('reads every count off one row', () {
      final week = WeeklySummary.fromJson({
        'devotions': 4,
        'scripture': 3,
        'journals': 2,
        'prayers': 3,
        'interactions': 1,
        'current_streak': 5,
      });

      expect(week.devotions, 4);
      expect(week.scripture, 3);
      expect(week.journals, 2);
      expect(week.prayers, 3);
      expect(week.interactions, 1);
      expect(week.currentStreak, 5);
      expect(week.isEmpty, isFalse);
    });

    test('reads nulls and missing keys as zero', () {
      // A youth with no rows at all is a legitimate answer, not a malformed
      // one — and it is the reading a parent most needs to see.
      final week = WeeklySummary.fromJson({
        'devotions': null,
        'journals': null,
      });

      expect(week.devotions, 0);
      expect(week.scripture, 0);
      expect(week.journals, 0);
      expect(week.prayers, 0);
      expect(week.interactions, 0);
      expect(week.currentStreak, 0);
      expect(week.isEmpty, isTrue);
    });
  });

  group('isEmpty', () {
    test('ignores the streak — it looks past this week', () {
      const week = WeeklySummary(
        devotions: 0,
        scripture: 0,
        journals: 0,
        prayers: 0,
        interactions: 0,
        currentStreak: 9,
      );
      expect(week.isEmpty, isTrue);
    });

    test('is false when any single count is non-zero', () {
      const week = WeeklySummary(
        devotions: 0,
        scripture: 0,
        journals: 0,
        prayers: 0,
        interactions: 1,
        currentStreak: 0,
      );
      expect(week.isEmpty, isFalse);
    });

    test('empty is all zeros', () {
      expect(WeeklySummary.empty.isEmpty, isTrue);
      expect(WeeklySummary.empty.currentStreak, 0);
    });
  });
}

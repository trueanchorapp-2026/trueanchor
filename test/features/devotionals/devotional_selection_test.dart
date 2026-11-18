import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/devotionals/domain/devotional.dart';
import 'package:trueanchor/features/devotionals/domain/devotional_audience.dart';
import 'package:trueanchor/features/devotionals/domain/devotional_selection.dart';

const _youth = DevotionalAudience.youth;
const _adult = DevotionalAudience.adult;

Devotional _row(String id, DateTime date, DevotionalAudience audience) =>
    Devotional(
      id: id,
      publishOn: date,
      title: id,
      scriptureReference: 'Ref',
      scriptureText: 'Text',
      translation: 'NIV',
      audience: audience,
    );

void main() {
  group('audiencesFor', () {
    test('always includes youth as the fallback track', () {
      expect(audiencesFor(_adult), {_adult, _youth});
      expect(audiencesFor(_youth), {_youth});
    });
  });

  group('pickForAudience', () {
    test('returns null for no rows', () {
      expect(pickForAudience(const [], _adult), isNull);
    });

    test('prefers the reader audience when both share the latest date', () {
      final day = DateTime(2026, 11, 23);
      final picked = pickForAudience(
        [_row('y', day, _youth), _row('a', day, _adult)],
        _adult,
      );
      expect(picked!.id, 'a');
    });

    test('a youth reader gets the youth row on a shared date', () {
      final day = DateTime(2026, 11, 23);
      final picked = pickForAudience(
        [_row('a', day, _adult), _row('y', day, _youth)],
        _youth,
      );
      expect(picked!.id, 'y');
    });

    test('fresher youth content beats a stale adult devotional', () {
      final picked = pickForAudience(
        [
          _row('a', DateTime(2026, 11, 20), _adult),
          _row('y', DateTime(2026, 11, 23), _youth),
        ],
        _adult,
      );
      expect(picked!.id, 'y');
    });

    test('an adult with no adult content reads the youth devotional', () {
      final picked = pickForAudience(
        [_row('y', DateTime(2026, 11, 23), _youth)],
        _adult,
      );
      expect(picked!.id, 'y');
    });
  });

  group('dedupeHistory', () {
    test('keeps one row per date, preferred audience, newest first', () {
      final history = dedupeHistory(
        [
          _row('y1', DateTime(2026, 11, 23), _youth),
          _row('a1', DateTime(2026, 11, 23), _adult),
          _row('y2', DateTime(2026, 11, 24), _youth),
        ],
        _adult,
      );
      expect(history.map((d) => d.id), ['y2', 'a1']);
    });
  });
}

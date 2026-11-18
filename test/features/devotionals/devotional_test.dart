import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/devotionals/domain/devotional.dart';
import 'package:trueanchor/features/devotionals/domain/devotional_audience.dart';

Map<String, dynamic> _json({
  String publishOn = '2026-08-01',
  Object? questions = const ['First?', 'Second?'],
  Object? activity = 'Write one sentence.',
  Object? copyright,
  String translation = 'WEB',
}) =>
    {
      'id': 'devo-1',
      'publish_on': publishOn,
      'title': 'An Anchor for the Soul',
      'scripture_reference': 'Hebrews 6:19',
      'scripture_text': 'We have this hope as an anchor for the soul.',
      'translation': translation,
      'copyright_notice': copyright,
      'body': 'First paragraph.\n\nSecond paragraph.',
      'discussion_questions': questions,
      'activity': activity,
    };

void main() {
  group('Devotional.fromJson', () {
    test('maps a text[] column into a List<String>', () {
      // Postgres arrays arrive from PostgREST as List<dynamic>, not
      // List<String>, so the cast has to be explicit.
      final devotional = Devotional.fromJson(_json());

      expect(devotional.discussionQuestions, ['First?', 'Second?']);
      expect(devotional.hasQuestions, isTrue);
    });

    test('an absent or empty question list becomes an empty list, not null', () {
      expect(Devotional.fromJson(_json(questions: null)).discussionQuestions,
          isEmpty);
      expect(Devotional.fromJson(_json(questions: const [])).discussionQuestions,
          isEmpty);
      expect(Devotional.fromJson(_json(questions: null)).hasQuestions, isFalse);
    });

    test('blank question entries are dropped rather than rendered as bullets', () {
      final devotional =
          Devotional.fromJson(_json(questions: const ['Real?', '  ', '']));

      expect(devotional.discussionQuestions, ['Real?']);
    });

    test('an absent activity is null and hasActivity is false', () {
      final devotional = Devotional.fromJson(_json(activity: null));

      expect(devotional.activity, isNull);
      expect(devotional.hasActivity, isFalse);
    });

    test('a blank activity is treated as absent', () {
      final devotional = Devotional.fromJson(_json(activity: '   '));

      expect(devotional.activity, isNull);
      expect(devotional.hasActivity, isFalse);
    });

    test('a public domain devotional carries no copyright notice', () {
      expect(Devotional.fromJson(_json()).copyrightNotice, isNull);
    });

    test('a licensed devotional keeps its notice for the footer', () {
      final devotional = Devotional.fromJson(
        _json(copyright: 'Scripture quotations taken from...'),
      );

      expect(devotional.copyrightNotice, 'Scripture quotations taken from...');
    });

    test('publish_on parses as a bare calendar date with no timezone drift', () {
      // A Postgres `date` has no time and no zone. Parsing must land on the
      // same day it names, or every devotional is off by one somewhere.
      final devotional = Devotional.fromJson(_json(publishOn: '2026-08-01'));

      expect(devotional.publishOn.year, 2026);
      expect(devotional.publishOn.month, 8);
      expect(devotional.publishOn.day, 1);
    });
  });

  group('isForToday', () {
    test('is true for the devotional written for that date', () {
      final devotional = Devotional.fromJson(_json(publishOn: '2026-08-01'));

      expect(devotional.isForToday(DateTime(2026, 8, 1, 13, 45)), isTrue);
    });

    test('is false for a fallback row, which is what shows the banner', () {
      // The repository returns the most recent devotional when today has none.
      // This flag is the only thing stopping the page from passing it off as
      // today's reading.
      final devotional = Devotional.fromJson(_json(publishOn: '2026-07-28'));

      expect(devotional.isForToday(DateTime(2026, 8, 1)), isFalse);
    });

    test('does not confuse the same day in a different month or year', () {
      final devotional = Devotional.fromJson(_json(publishOn: '2026-08-01'));

      expect(devotional.isForToday(DateTime(2026, 9, 1)), isFalse);
      expect(devotional.isForToday(DateTime(2025, 8, 1)), isFalse);
    });
  });

  group('structured (weekly) rows', () {
    Map<String, dynamic> structured() => {
          ..._json(questions: null, activity: null),
          'body': null,
          'audience': 'adult',
          'day_number': 2,
          'theme': {
            'id': 'theme-1',
            'audience': 'adult',
            'title': 'Courage',
            'starts_on': '2026-11-23',
          },
          'deeper_reference': 'Acts 5:17-32',
          'deeper_text': 'Then the high priest...',
          'deeper_translation': 'ESV',
          'upward_body': 'Courage looks first to God.',
          'upward_questions': ['Whose voice first?'],
          'inward_questions': ['Where is the pull?', 'What would it look like?'],
          'outward_body': 'Obedience shows up in real choices.',
          'outward_prompt': 'Legacy prompt',
          'self_application_questions': ['One', 'Two', 'Three'],
          'love_in_action': 'Choose one small act.',
          'love_in_action_questions': ['What step?'],
        };

    test('parses sections, audience, theme and day number', () {
      final d = Devotional.fromJson(structured());

      expect(d.isStructured, isTrue);
      expect(d.body, isNull);
      expect(d.audience, DevotionalAudience.adult);
      expect(d.dayNumber, 2);
      expect(d.theme?.title, 'Courage');
      expect(d.theme?.startsOn, DateTime(2026, 11, 23));
      expect(d.themeLabel, 'Courage · Day 2');
      expect(d.upwardText, 'Courage looks first to God.');
      expect(d.selfApplicationQuestions, hasLength(3));
      expect(d.loveInActionQuestions, ['What step?']);
    });

    test('inward prompts prefer the structured questions', () {
      final d = Devotional.fromJson(structured());
      expect(d.inwardPrompts, ['Where is the pull?', 'What would it look like?']);
    });

    test('outward text prefers outward_body over the legacy prompt', () {
      expect(Devotional.fromJson(structured()).outwardText,
          'Obedience shows up in real choices.');
    });

    test('the Go Deeper label uses its own translation', () {
      expect(Devotional.fromJson(structured()).deeperAttribution,
          'Acts 5:17-32 (ESV)');
    });
  });

  group('legacy rows', () {
    test('default to youth, are not structured, and keep their fallbacks', () {
      final d = Devotional.fromJson(_json());

      expect(d.audience, DevotionalAudience.youth);
      expect(d.isStructured, isFalse);
      expect(d.theme, isNull);
      expect(d.themeLabel, isNull);
      expect(d.upwardText, 'First paragraph.\n\nSecond paragraph.');
      expect(d.inwardPrompts, ['First?', 'Second?']);
      expect(d.outwardText, 'Write one sentence.');
      expect(d.deeperAttribution, isNull);
    });
  });

  group('attribution', () {
    test('pairs the reference with the translation', () {
      expect(Devotional.fromJson(_json()).attribution, 'Hebrews 6:19 (WEB)');
    });

    test('omits empty parentheses when no translation is recorded', () {
      final devotional = Devotional.fromJson(_json(translation: ''));

      expect(devotional.attribution, 'Hebrews 6:19');
    });
  });
}

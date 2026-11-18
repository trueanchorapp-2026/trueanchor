// Turns the authored weekly devotional JSON under content/devotionals/ into an
// idempotent seed script at supabase/seed/devotionals_seed.sql.
//
// Run from the repository root:
//
//     dart run tool/build_devotional_seed.dart
//
// or via scripts/build_devotionals.ps1, which finds the SDK for you.
//
// Layout: one file per week, content/devotionals/<audience>/<starts_on>-<slug>.json
// (see content/devotionals/README.md). content/devotionals/_archive/ is never
// read — it holds the pre-weekly daily files, whose rows stay in the database.
//
// The generated file is checked in and pasted into the Supabase SQL Editor,
// the same way every migration in this repo is applied. It is regenerated
// wholesale every run, so never edit it by hand — edit the JSON and re-run.
// It upserts and never deletes.
//
// Uses only dart:io and dart:convert so it needs no pubspec dependency.

import 'dart:convert';
import 'dart:io';

const _contentDir = 'content/devotionals';
const _outputPath = 'supabase/seed/devotionals_seed.sql';
const _audiences = ['youth', 'adult'];

/// The dollar-quote tag used for every string in the generated SQL. Inside
/// $ta$...$ta$ Postgres treats the contents literally, so apostrophes,
/// newlines and backslashes in devotional prose need no escaping at all —
/// which is exactly why content containing the tag itself is rejected rather
/// than escaped around.
const _tag = r'$ta$';

const _weekKeys = {
  'audience',
  'theme',
  'theme_summary',
  'starts_on',
  'translation',
  'copyright_notice',
  'days',
};

const _dayTextRequired = [
  'title',
  'scripture_reference',
  'scripture_text',
  'context',
  'deeper_reference',
  'deeper_text',
  'summary',
  'upward',
  'inward',
  'outward',
  'prayer',
  'love_in_action',
];

const _dayTextOptional = [
  'translation',
  'copyright_notice',
  'deeper_translation',
];

const _dayLists = [
  'upward_questions',
  'inward_questions',
  'outward_questions',
  'self_application',
  'love_in_action_questions',
];

const _maxQuestions = 5;

void main(List<String> args) {
  final root = Directory(_contentDir);
  if (!root.existsSync()) {
    _fail('No $_contentDir directory. Run this from the repository root.');
  }

  final errors = <String>[];
  final weeks = <_Week>[];
  final seenDates = <String, String>{};
  var fileCount = 0;

  for (final audience in _audiences) {
    final dir = Directory('$_contentDir/$audience');
    if (!dir.existsSync()) continue;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      fileCount++;
      final name = '$audience/${file.uri.pathSegments.last}';
      final week = _parseWeek(file, name, audience, errors);
      if (week == null) continue;

      for (final day in week.days) {
        final key = '${week.audience} ${day.publishOn}';
        final clash = seenDates[key];
        if (clash != null) {
          errors.add('$name: day ${day.day} publishes on ${day.publishOn}, '
              'which $clash already uses for ${week.audience}. Each date may '
              'appear once per audience.');
        } else {
          seenDates[key] = name;
        }
      }
      weeks.add(week);
    }
  }

  if (fileCount == 0) {
    _fail('No weekly .json files in $_contentDir/{${_audiences.join(',')}}/.');
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Devotional content is not valid:\n');
    for (final error in errors) {
      stderr.writeln('  - $error');
    }
    stderr.writeln('\nNothing was written. Fix the above and re-run.');
    exitCode = 1;
    return;
  }

  weeks.sort((a, b) => '${a.audience}${a.startsOn}'
      .compareTo('${b.audience}${b.startsOn}'));

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(_render(weeks, fileCount));

  final dayCount = weeks.fold<int>(0, (sum, w) => sum + w.days.length);
  stdout.writeln('Wrote $_outputPath (${weeks.length} week'
      '${weeks.length == 1 ? '' : 's'}, $dayCount devotional'
      '${dayCount == 1 ? '' : 's'}).');
  for (final week in weeks) {
    stdout.writeln('  ${week.audience}  ${week.startsOn}  ${week.theme}  '
        '(${week.days.length} days, ${week.days.first.publishOn} to '
        '${week.days.last.publishOn})');
  }
  stdout.writeln('Paste it into the Supabase SQL Editor to apply.');
}

_Week? _parseWeek(
  File file,
  String name,
  String folderAudience,
  List<String> errors,
) {
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    errors.add('$name: not valid JSON — ${error.message}');
    return null;
  }
  if (decoded is! Map<String, dynamic>) {
    errors.add('$name: expected a JSON object at the top level.');
    return null;
  }

  final before = errors.length;

  _rejectUnknown(name, decoded, _weekKeys, errors);
  _rejectTag(name, decoded, errors);

  final audience = _requireText(name, decoded, 'audience', errors);
  if (audience != null && audience != folderAudience) {
    errors.add('$name: "audience" is "$audience" but the file is in the '
        '$folderAudience/ folder. They must match.');
  }
  final theme = _requireText(name, decoded, 'theme', errors);
  final translation = _requireText(name, decoded, 'translation', errors);
  final themeSummary = _optionalText(name, decoded, 'theme_summary', errors);
  final copyright = _optionalText(name, decoded, 'copyright_notice', errors);

  final startsOnRaw = _requireText(name, decoded, 'starts_on', errors);
  DateTime? startsOn;
  if (startsOnRaw != null) {
    startsOn = _parseDate(startsOnRaw);
    if (startsOn == null) {
      errors.add('$name: "starts_on" "$startsOnRaw" is not a valid yyyy-MM-dd '
          'date.');
    } else if (!file.uri.pathSegments.last.startsWith('$startsOnRaw-')) {
      // The filename is the index: a directory listing shows every week's
      // start date before anyone runs this script.
      errors.add('$name: filename must start with starts_on — expected '
          '"$startsOnRaw-<slug>.json".');
    }
  }

  final rawDays = decoded['days'];
  final days = <_Day>[];
  if (rawDays is! List || rawDays.isEmpty) {
    errors.add('$name: "days" must be a non-empty list.');
  } else {
    final seen = <int>{};
    for (var i = 0; i < rawDays.length; i++) {
      final raw = rawDays[i];
      final label = '$name day #${i + 1}';
      if (raw is! Map<String, dynamic>) {
        errors.add('$label: expected an object.');
        continue;
      }
      final day = _parseDay(
        label,
        raw,
        startsOn: startsOn,
        weekTranslation: translation,
        weekCopyright: copyright,
        errors: errors,
      );
      if (day == null) continue;
      if (!seen.add(day.day)) {
        errors.add('$label: "day" ${day.day} appears more than once.');
        continue;
      }
      days.add(day);
    }
  }

  if (errors.length != before) return null;

  days.sort((a, b) => a.day.compareTo(b.day));
  return _Week(
    audience: audience!,
    theme: theme!,
    themeSummary: themeSummary,
    startsOn: startsOnRaw!,
    days: days,
  );
}

_Day? _parseDay(
  String label,
  Map<String, dynamic> raw, {
  required DateTime? startsOn,
  required String? weekTranslation,
  required String? weekCopyright,
  required List<String> errors,
}) {
  final before = errors.length;
  _rejectUnknown(
    label,
    raw,
    {'day', ..._dayTextRequired, ..._dayTextOptional, ..._dayLists},
    errors,
  );

  final dayNumber = raw['day'];
  if (dayNumber is! int || dayNumber < 1 || dayNumber > 7) {
    errors.add('$label: "day" must be a whole number from 1 to 7.');
  }

  final text = <String, String>{};
  for (final key in _dayTextRequired) {
    final value = _requireText(label, raw, key, errors);
    if (value != null) text[key] = value;
  }
  final optional = <String, String?>{
    for (final key in _dayTextOptional) key: _optionalText(label, raw, key, errors),
  };
  final lists = <String, List<String>>{
    for (final key in _dayLists) key: _questions(label, raw, key, errors),
  };

  if (errors.length != before || startsOn == null || dayNumber is! int) {
    return null;
  }

  return _Day(
    day: dayNumber,
    publishOn: _formatDate(startsOn.add(Duration(days: dayNumber - 1))),
    title: text['title']!,
    scriptureReference: text['scripture_reference']!,
    scriptureText: text['scripture_text']!,
    translation: optional['translation'] ?? weekTranslation!,
    copyrightNotice: optional['copyright_notice'] ?? weekCopyright,
    context: text['context']!,
    deeperReference: text['deeper_reference']!,
    deeperText: text['deeper_text']!,
    deeperTranslation: optional['deeper_translation'],
    summary: text['summary']!,
    upward: text['upward']!,
    upwardQuestions: lists['upward_questions']!,
    inward: text['inward']!,
    inwardQuestions: lists['inward_questions']!,
    outward: text['outward']!,
    outwardQuestions: lists['outward_questions']!,
    prayer: text['prayer']!,
    selfApplication: lists['self_application']!,
    loveInAction: text['love_in_action']!,
    loveInActionQuestions: lists['love_in_action_questions']!,
  );
}

// --------------------------------------------------------- validation ---

void _rejectUnknown(
  String label,
  Map<String, dynamic> map,
  Set<String> allowed,
  List<String> errors,
) {
  // Catches typos like "sciprture_text", which would otherwise silently drop
  // the field.
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      errors.add('$label: unknown field "$key". Allowed fields are '
          '${(allowed.toList()..sort()).join(', ')}.');
    }
  }
}

/// Any occurrence of the dollar-quote tag would end the literal early and
/// turn the rest of the devotional into SQL.
void _rejectTag(String label, Object? value, List<String> errors) {
  if (value is String && value.contains(_tag)) {
    errors.add('$label: text contains the literal $_tag, which is reserved by '
        'the seed generator. Remove it.');
  } else if (value is List) {
    for (final item in value) {
      _rejectTag(label, item, errors);
    }
  } else if (value is Map) {
    for (final item in value.values) {
      _rejectTag(label, item, errors);
    }
  }
}

String? _requireText(
  String label,
  Map<String, dynamic> map,
  String key,
  List<String> errors,
) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    errors.add('$label: "$key" is required and must be a non-empty string.');
    return null;
  }
  return value.trim();
}

String? _optionalText(
  String label,
  Map<String, dynamic> map,
  String key,
  List<String> errors,
) {
  final value = map[key];
  if (value == null) return null;
  if (value is! String) {
    errors.add('$label: "$key" must be a string or null.');
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> _questions(
  String label,
  Map<String, dynamic> map,
  String key,
  List<String> errors,
) {
  final value = map[key];
  if (value is! List || value.isEmpty) {
    errors.add('$label: "$key" must be a list of 1 to $_maxQuestions '
        'questions.');
    return const [];
  }
  final out = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      errors.add('$label: every entry in "$key" must be a non-empty string.');
      return const [];
    }
    out.add(item.trim());
  }
  if (out.length > _maxQuestions) {
    errors.add('$label: "$key" has ${out.length} entries — the limit is '
        '$_maxQuestions.');
  }
  return out;
}

DateTime? _parseDate(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return null;
  final parsed = DateTime.tryParse(value);
  // Reject roll-overs like 2026-02-30 → 2026-03-02.
  if (parsed == null || _formatDate(parsed) != value) return null;
  return parsed;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

// ------------------------------------------------------------- render ---

String _render(List<_Week> weeks, int fileCount) {
  final buffer = StringBuffer()
    ..writeln('-- ${'=' * 74}')
    ..writeln('-- TrueAnchor — devotional content seed')
    ..writeln('--')
    ..writeln('-- GENERATED by tool/build_devotional_seed.dart — do not edit '
        'by hand.')
    ..writeln('-- Source: $_contentDir/{${_audiences.join(',')}} ($fileCount '
        'file${fileCount == 1 ? '' : 's'})')
    ..writeln('--')
    ..writeln('-- Idempotent: themes upsert on (audience, starts_on) and '
        'devotionals on')
    ..writeln('-- (audience, publish_on), so re-running updates rows in place. '
        'Nothing is')
    ..writeln('-- deleted. Requires migration 0032 and app_admin or the SQL '
        'Editor role.')
    ..writeln('-- ${'=' * 74}')
    ..writeln()
    ..writeln('begin;');

  for (final week in weeks) {
    final audience = "'${week.audience}'::public.devotional_audience";
    final startsOn = "'${week.startsOn}'::date";

    buffer
      ..writeln()
      ..writeln('-- ${week.audience} · ${week.theme} · week of '
          '${week.startsOn}')
      ..writeln()
      ..writeln('insert into public.devotional_themes '
          '(audience, title, summary, starts_on)')
      ..writeln('values ($audience, ${_literal(week.theme)}, '
          '${_literal(week.themeSummary)}, $startsOn)')
      ..writeln('on conflict (audience, starts_on) do update set')
      ..writeln('  title      = excluded.title,')
      ..writeln('  summary    = excluded.summary,')
      ..writeln('  updated_at = now();')
      ..writeln()
      ..writeln('insert into public.devotionals')
      ..writeln('  (audience, theme_id, day_number, publish_on, title,')
      ..writeln('   scripture_reference, scripture_text, translation, '
          'copyright_notice,')
      ..writeln('   context, deeper_reference, deeper_text, '
          'deeper_translation, summary,')
      ..writeln('   upward_body, upward_questions, inward_body, '
          'inward_questions,')
      ..writeln('   outward_body, outward_questions, prayer, '
          'self_application_questions,')
      ..writeln('   love_in_action, love_in_action_questions)')
      ..writeln('select')
      ..writeln('  $audience,')
      ..writeln('  (select id from public.devotional_themes')
      ..writeln('    where audience = $audience and starts_on = $startsOn),')
      ..writeln('  v.*')
      ..writeln('from (values');

    for (var i = 0; i < week.days.length; i++) {
      final d = week.days[i];
      final last = i == week.days.length - 1;
      buffer
        ..writeln('  ( -- day ${d.day}')
        ..writeln('    ${d.day}::smallint,')
        ..writeln("    '${d.publishOn}'::date,")
        ..writeln('    ${_literal(d.title)},')
        ..writeln('    ${_literal(d.scriptureReference)},')
        ..writeln('    ${_literal(d.scriptureText)},')
        ..writeln('    ${_literal(d.translation)},')
        ..writeln('    ${_literal(d.copyrightNotice)}::text,')
        ..writeln('    ${_literal(d.context)},')
        ..writeln('    ${_literal(d.deeperReference)},')
        ..writeln('    ${_literal(d.deeperText)},')
        ..writeln('    ${_literal(d.deeperTranslation)}::text,')
        ..writeln('    ${_literal(d.summary)},')
        ..writeln('    ${_literal(d.upward)},')
        ..writeln('    ${_arrayLiteral(d.upwardQuestions)},')
        ..writeln('    ${_literal(d.inward)},')
        ..writeln('    ${_arrayLiteral(d.inwardQuestions)},')
        ..writeln('    ${_literal(d.outward)},')
        ..writeln('    ${_arrayLiteral(d.outwardQuestions)},')
        ..writeln('    ${_literal(d.prayer)},')
        ..writeln('    ${_arrayLiteral(d.selfApplication)},')
        ..writeln('    ${_literal(d.loveInAction)},')
        ..writeln('    ${_arrayLiteral(d.loveInActionQuestions)}')
        ..writeln('  )${last ? '' : ','}');
    }

    buffer
      ..writeln(') as v')
      ..writeln('on conflict (audience, publish_on) do update set')
      ..writeln('  theme_id                   = excluded.theme_id,')
      ..writeln('  day_number                 = excluded.day_number,')
      ..writeln('  title                      = excluded.title,')
      ..writeln('  scripture_reference        = excluded.scripture_reference,')
      ..writeln('  scripture_text             = excluded.scripture_text,')
      ..writeln('  translation                = excluded.translation,')
      ..writeln('  copyright_notice           = excluded.copyright_notice,')
      ..writeln('  context                    = excluded.context,')
      ..writeln('  deeper_reference           = excluded.deeper_reference,')
      ..writeln('  deeper_text                = excluded.deeper_text,')
      ..writeln('  deeper_translation         = excluded.deeper_translation,')
      ..writeln('  summary                    = excluded.summary,')
      ..writeln('  upward_body                = excluded.upward_body,')
      ..writeln('  upward_questions           = excluded.upward_questions,')
      ..writeln('  inward_body                = excluded.inward_body,')
      ..writeln('  inward_questions           = excluded.inward_questions,')
      ..writeln('  outward_body               = excluded.outward_body,')
      ..writeln('  outward_questions          = excluded.outward_questions,')
      ..writeln('  prayer                     = excluded.prayer,')
      ..writeln('  self_application_questions = '
          'excluded.self_application_questions,')
      ..writeln('  love_in_action             = excluded.love_in_action,')
      ..writeln('  love_in_action_questions   = '
          'excluded.love_in_action_questions,')
      ..writeln('  updated_at                 = now();');
  }

  buffer
    ..writeln()
    ..writeln('commit;');
  return buffer.toString();
}

String _literal(String? value) => value == null ? 'null' : '$_tag$value$_tag';

String _arrayLiteral(List<String> items) => items.isEmpty
    ? "'{}'::text[]"
    : 'array[${items.map(_literal).join(', ')}]::text[]';

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

class _Week {
  const _Week({
    required this.audience,
    required this.theme,
    required this.themeSummary,
    required this.startsOn,
    required this.days,
  });

  final String audience;
  final String theme;
  final String? themeSummary;
  final String startsOn;
  final List<_Day> days;
}

class _Day {
  const _Day({
    required this.day,
    required this.publishOn,
    required this.title,
    required this.scriptureReference,
    required this.scriptureText,
    required this.translation,
    required this.copyrightNotice,
    required this.context,
    required this.deeperReference,
    required this.deeperText,
    required this.deeperTranslation,
    required this.summary,
    required this.upward,
    required this.upwardQuestions,
    required this.inward,
    required this.inwardQuestions,
    required this.outward,
    required this.outwardQuestions,
    required this.prayer,
    required this.selfApplication,
    required this.loveInAction,
    required this.loveInActionQuestions,
  });

  final int day;
  final String publishOn;
  final String title;
  final String scriptureReference;
  final String scriptureText;
  final String translation;
  final String? copyrightNotice;
  final String context;
  final String deeperReference;
  final String deeperText;
  final String? deeperTranslation;
  final String summary;
  final String upward;
  final List<String> upwardQuestions;
  final String inward;
  final List<String> inwardQuestions;
  final String outward;
  final List<String> outwardQuestions;
  final String prayer;
  final List<String> selfApplication;
  final String loveInAction;
  final List<String> loveInActionQuestions;
}

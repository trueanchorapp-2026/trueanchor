// Turns the authored devotional JSON under content/devotionals/ into an
// idempotent seed script at supabase/seed/devotionals_seed.sql.
//
// Run from the repository root:
//
//     dart run tool/build_devotional_seed.dart
//
// or via scripts/build_devotionals.ps1, which finds the SDK for you.
//
// The generated file is checked in and pasted into the Supabase SQL Editor,
// the same way every migration in this repo is applied. It is regenerated
// wholesale every run, so never edit it by hand — edit the JSON and re-run.
//
// This is deliberately not a numbered migration: the files in
// supabase/migrations/ are hand-written schema and are never rewritten, while
// this one is derived output that changes every time content is added.
//
// Uses only dart:io and dart:convert so it needs no pubspec dependency.

import 'dart:convert';
import 'dart:io';

const _contentDir = 'content/devotionals';
const _outputPath = 'supabase/seed/devotionals_seed.sql';

/// The dollar-quote tag used for every string in the generated SQL. Inside
/// $ta$...$ta$ Postgres treats the contents literally, so apostrophes,
/// newlines and backslashes in devotional prose need no escaping at all —
/// which is exactly why content containing the tag itself is rejected rather
/// than escaped around.
const _tag = r'$ta$';

const _allowedKeys = {
  'publish_on',
  'title',
  'scripture_reference',
  'scripture_text',
  'translation',
  'copyright_notice',
  'body',
  'discussion_questions',
  'activity',
};

/// Every field that must be present and non-blank.
const _requiredKeys = [
  'publish_on',
  'title',
  'scripture_reference',
  'scripture_text',
  'translation',
  'body',
];

const _maxQuestions = 5;

void main(List<String> args) {
  final directory = Directory(_contentDir);
  if (!directory.existsSync()) {
    _fail('No $_contentDir directory. Run this from the repository root.');
  }

  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    _fail('No .json files in $_contentDir.');
  }

  final errors = <String>[];
  final devotionals = <_Devotional>[];
  final seenDates = <String, String>{};

  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final parsed = _parse(file, name, errors);
    if (parsed == null) continue;

    final clash = seenDates[parsed.publishOn];
    if (clash != null) {
      errors.add('$name: publish_on ${parsed.publishOn} is already used by '
          '$clash. Each date may appear once — publish_on is unique.');
      continue;
    }
    seenDates[parsed.publishOn] = name;
    devotionals.add(parsed);
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

  devotionals.sort((a, b) => a.publishOn.compareTo(b.publishOn));

  final output = File(_outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(_render(devotionals, files.length));

  stdout.writeln('Wrote $_outputPath '
      '(${devotionals.length} devotional${devotionals.length == 1 ? '' : 's'}, '
      '${devotionals.first.publishOn} to ${devotionals.last.publishOn}).');
  stdout.writeln('Paste it into the Supabase SQL Editor to apply.');
}

_Devotional? _parse(File file, String name, List<String> errors) {
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

  // Catches typos like "sciprture_text", which would otherwise silently drop
  // the field and emit a devotional with an empty verse.
  for (final key in decoded.keys) {
    if (!_allowedKeys.contains(key)) {
      errors.add('$name: unknown field "$key". Allowed fields are '
          '${(_allowedKeys.toList()..sort()).join(', ')}.');
    }
  }

  for (final key in _requiredKeys) {
    final value = decoded[key];
    if (value is! String || value.trim().isEmpty) {
      errors.add('$name: "$key" is required and must be a non-empty string.');
    }
  }

  final publishOn = decoded['publish_on'];
  if (publishOn is String && publishOn.trim().isNotEmpty) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(publishOn) ||
        DateTime.tryParse(publishOn) == null) {
      errors.add('$name: publish_on "$publishOn" is not a valid yyyy-MM-dd '
          'date.');
    } else if (name != '$publishOn.json') {
      // The filename is the index. Keeping them in step means a duplicate date
      // is visible in a directory listing before anyone runs this script.
      errors.add('$name: filename must match publish_on — expected '
          '"$publishOn.json".');
    }
  }

  final questions = decoded['discussion_questions'];
  final parsedQuestions = <String>[];
  if (questions == null) {
    errors.add('$name: "discussion_questions" is required. Give it 1 to '
        '$_maxQuestions questions.');
  } else if (questions is! List) {
    errors.add('$name: "discussion_questions" must be a list of strings.');
  } else {
    for (final question in questions) {
      if (question is! String || question.trim().isEmpty) {
        errors.add('$name: every discussion question must be a non-empty '
            'string.');
        break;
      }
      parsedQuestions.add(question.trim());
    }
    if (parsedQuestions.isEmpty && questions.isEmpty) {
      errors.add('$name: "discussion_questions" must have at least one '
          'question.');
    } else if (parsedQuestions.length > _maxQuestions) {
      errors.add('$name: ${parsedQuestions.length} discussion questions — the '
          'limit is $_maxQuestions.');
    }
  }

  for (final key in ['copyright_notice', 'activity']) {
    final value = decoded[key];
    if (value != null && value is! String) {
      errors.add('$name: "$key" must be a string or null.');
    }
  }

  // Any occurrence of the dollar-quote tag would end the literal early and
  // turn the rest of the devotional into SQL.
  decoded.forEach((key, value) {
    final texts = value is List ? value.whereType<String>() : [if (value is String) value];
    for (final text in texts) {
      if (text.contains(_tag)) {
        errors.add('$name: "$key" contains the literal $_tag, which is '
            'reserved by the seed generator. Remove it.');
      }
    }
  });

  if (errors.length != before) return null;

  return _Devotional(
    publishOn: (decoded['publish_on'] as String).trim(),
    title: (decoded['title'] as String).trim(),
    scriptureReference: (decoded['scripture_reference'] as String).trim(),
    scriptureText: (decoded['scripture_text'] as String).trim(),
    translation: (decoded['translation'] as String).trim(),
    copyrightNotice: _blankToNull(decoded['copyright_notice'] as String?),
    body: (decoded['body'] as String).trim(),
    discussionQuestions: parsedQuestions,
    activity: _blankToNull(decoded['activity'] as String?),
  );
}

String _render(List<_Devotional> devotionals, int fileCount) {
  final buffer = StringBuffer()
    ..writeln('-- ${'=' * 74}')
    ..writeln('-- TrueAnchor — devotional content seed')
    ..writeln('--')
    ..writeln('-- GENERATED by tool/build_devotional_seed.dart — do not edit '
        'by hand.')
    ..writeln('-- Source: $_contentDir ($fileCount file'
        '${fileCount == 1 ? '' : 's'})')
    ..writeln('--')
    ..writeln('-- Idempotent on publish_on: re-running updates existing rows '
        'in place rather')
    ..writeln('-- than duplicating them, so this is safe to paste as often as '
        'content changes.')
    ..writeln('-- Requires app_admin (devotionals_insert) or the SQL Editor\'s '
        'elevated role.')
    ..writeln('-- ${'=' * 74}')
    ..writeln()
    ..writeln('begin;')
    ..writeln()
    ..writeln('insert into public.devotionals')
    ..writeln('  (publish_on, title, scripture_reference, scripture_text, '
        'translation,')
    ..writeln('   copyright_notice, body, discussion_questions, activity)')
    ..writeln('values');

  for (var i = 0; i < devotionals.length; i++) {
    final d = devotionals[i];
    final last = i == devotionals.length - 1;
    buffer
      ..writeln('  (')
      ..writeln("    '${d.publishOn}',")
      ..writeln('    ${_literal(d.title)},')
      ..writeln('    ${_literal(d.scriptureReference)},')
      ..writeln('    ${_literal(d.scriptureText)},')
      ..writeln('    ${_literal(d.translation)},')
      ..writeln('    ${_literal(d.copyrightNotice)},')
      ..writeln('    ${_literal(d.body)},')
      ..writeln('    ${_arrayLiteral(d.discussionQuestions)},')
      ..writeln('    ${_literal(d.activity)}')
      ..writeln('  )${last ? '' : ','}');
  }

  buffer
    ..writeln('on conflict (publish_on) do update set')
    ..writeln('  title                = excluded.title,')
    ..writeln('  scripture_reference  = excluded.scripture_reference,')
    ..writeln('  scripture_text       = excluded.scripture_text,')
    ..writeln('  translation          = excluded.translation,')
    ..writeln('  copyright_notice     = excluded.copyright_notice,')
    ..writeln('  body                 = excluded.body,')
    ..writeln('  discussion_questions = excluded.discussion_questions,')
    ..writeln('  activity             = excluded.activity,')
    ..writeln('  updated_at           = now();')
    ..writeln()
    ..writeln('commit;');

  return buffer.toString();
}

String _literal(String? value) => value == null ? 'null' : '$_tag$value$_tag';

String _arrayLiteral(List<String> items) => items.isEmpty
    ? "'{}'::text[]"
    : 'array[${items.map(_literal).join(', ')}]::text[]';

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

class _Devotional {
  const _Devotional({
    required this.publishOn,
    required this.title,
    required this.scriptureReference,
    required this.scriptureText,
    required this.translation,
    required this.copyrightNotice,
    required this.body,
    required this.discussionQuestions,
    required this.activity,
  });

  final String publishOn;
  final String title;
  final String scriptureReference;
  final String scriptureText;
  final String translation;
  final String? copyrightNotice;
  final String body;
  final List<String> discussionQuestions;
  final String? activity;
}

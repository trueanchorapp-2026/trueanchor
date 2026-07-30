/// A row of `public.devotionals`: one day's native discipleship content.
///
/// Devotionals are global — unlike every other entity in the app they carry no
/// church_id, because every church reads the same devotional on the same date.
///
/// There is no `toInsertJson` here on purpose: nothing in the app authors a
/// devotional. Content is written as JSON under `content/devotionals/` and
/// loaded through the generated seed script, and `devotionals_insert` restricts
/// direct writes to app_admin.
class Devotional {
  const Devotional({
    required this.id,
    required this.publishOn,
    required this.title,
    required this.scriptureReference,
    required this.scriptureText,
    required this.translation,
    required this.body,
    this.copyrightNotice,
    this.discussionQuestions = const [],
    this.activity,
  });

  factory Devotional.fromJson(Map<String, dynamic> json) {
    return Devotional(
      id: json['id'] as String,
      publishOn: _parseDate(json['publish_on'] as String?),
      title: json['title'] as String? ?? '',
      scriptureReference: json['scripture_reference'] as String? ?? '',
      scriptureText: json['scripture_text'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      copyrightNotice: _blankToNull(json['copyright_notice'] as String?),
      body: json['body'] as String? ?? '',
      discussionQuestions: _stringList(json['discussion_questions']),
      activity: _blankToNull(json['activity'] as String?),
    );
  }

  final String id;

  /// The calendar date this devotional is published for. A bare Postgres
  /// `date`, so it carries no time and no zone.
  final DateTime publishOn;

  final String title;
  final String scriptureReference;
  final String scriptureText;

  /// Which translation [scriptureText] is quoted from, for attribution.
  final String translation;

  /// The notice a licensed translation requires on any screen showing verse
  /// text. Null for public domain texts, which need none.
  final String? copyrightNotice;

  final String body;
  final List<String> discussionQuestions;
  final String? activity;

  /// True when this really is the devotional written for [today], false when
  /// it arrived through the fallback (the most recent one published on or
  /// before today, because nothing was published for today itself).
  ///
  /// The page uses this to label the difference rather than passing an older
  /// devotional off as today's.
  bool isForToday(DateTime today) =>
      publishOn.year == today.year &&
      publishOn.month == today.month &&
      publishOn.day == today.day;

  bool get hasActivity => activity != null;

  bool get hasQuestions => discussionQuestions.isNotEmpty;

  /// The line shown under the scripture block, e.g. "Hebrews 6:19 (WEB)".
  String get attribution => translation.trim().isEmpty
      ? scriptureReference
      : '$scriptureReference ($translation)';
}

/// Postgres `date` arrives as a bare yyyy-MM-dd with no zone, so parsing it
/// yields local midnight — which is what [Devotional.isForToday] compares
/// against. Falls back to the epoch rather than `now()` so a malformed row is
/// visibly wrong instead of silently masquerading as today's devotional.
DateTime _parseDate(String? value) =>
    DateTime.tryParse(value ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

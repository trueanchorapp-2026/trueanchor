import 'devotional_audience.dart';
import 'devotional_theme.dart';

/// A row of `public.devotionals`: one day's native discipleship content.
///
/// Devotionals are global — unlike every other entity in the app they carry no
/// church_id, because every church reads the same devotional on the same date.
/// Each is written for one [audience], and since 0032 most belong to a weekly
/// [theme] as one of its days.
///
/// Two shapes exist:
///  * **Structured** ([isStructured]) — the weekly format with Context, Go
///    Deeper, Summary, Upward/Inward/Outward, Prayer, Self-Application and Love
///    in Action sections.
///  * **Legacy** — the original single [body] + [discussionQuestions] +
///    [activity] rows, kept readable.
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
    this.audience = DevotionalAudience.youth,
    this.theme,
    this.dayNumber,
    this.copyrightNotice,
    this.body,
    this.discussionQuestions = const [],
    this.activity,
    this.outwardPrompt,
    this.context,
    this.deeperReference,
    this.deeperText,
    this.deeperTranslation,
    this.summary,
    this.upwardBody,
    this.upwardQuestions = const [],
    this.inwardBody,
    this.inwardQuestions = const [],
    this.outwardBody,
    this.outwardQuestions = const [],
    this.prayer,
    this.selfApplicationQuestions = const [],
    this.loveInAction,
    this.loveInActionQuestions = const [],
  });

  factory Devotional.fromJson(Map<String, dynamic> json) {
    final theme = json['theme'];
    return Devotional(
      id: json['id'] as String,
      publishOn: _parseDate(json['publish_on'] as String?),
      title: json['title'] as String? ?? '',
      scriptureReference: json['scripture_reference'] as String? ?? '',
      scriptureText: json['scripture_text'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      audience: DevotionalAudience.fromWire(json['audience'] as String?),
      theme: theme is Map<String, dynamic>
          ? DevotionalTheme.fromJson(theme)
          : null,
      dayNumber: (json['day_number'] as num?)?.toInt(),
      copyrightNotice: _text(json['copyright_notice']),
      body: _text(json['body']),
      discussionQuestions: _stringList(json['discussion_questions']),
      activity: _text(json['activity']),
      outwardPrompt: _text(json['outward_prompt']),
      context: _text(json['context']),
      deeperReference: _text(json['deeper_reference']),
      deeperText: _text(json['deeper_text']),
      deeperTranslation: _text(json['deeper_translation']),
      summary: _text(json['summary']),
      upwardBody: _text(json['upward_body']),
      upwardQuestions: _stringList(json['upward_questions']),
      inwardBody: _text(json['inward_body']),
      inwardQuestions: _stringList(json['inward_questions']),
      outwardBody: _text(json['outward_body']),
      outwardQuestions: _stringList(json['outward_questions']),
      prayer: _text(json['prayer']),
      selfApplicationQuestions:
          _stringList(json['self_application_questions']),
      loveInAction: _text(json['love_in_action']),
      loveInActionQuestions: _stringList(json['love_in_action_questions']),
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

  final DevotionalAudience audience;

  /// The weekly theme this devotional belongs to. Null for legacy rows.
  final DevotionalTheme? theme;

  /// Which day of [theme] this is (1–7). Null for legacy rows.
  final int? dayNumber;

  /// The notice(s) a licensed translation requires on any screen showing verse
  /// text. Null for public domain texts, which need none.
  final String? copyrightNotice;

  // — Legacy shape —
  final String? body;
  final List<String> discussionQuestions;
  final String? activity;
  final String? outwardPrompt;

  // — Structured shape —
  final String? context;
  final String? deeperReference;
  final String? deeperText;

  /// Translation of [deeperText] when it differs from [translation].
  final String? deeperTranslation;

  final String? summary;
  final String? upwardBody;
  final List<String> upwardQuestions;
  final String? inwardBody;
  final List<String> inwardQuestions;
  final String? outwardBody;
  final List<String> outwardQuestions;
  final String? prayer;
  final List<String> selfApplicationQuestions;
  final String? loveInAction;
  final List<String> loveInActionQuestions;

  /// True for the weekly sectioned format, false for legacy rows.
  bool get isStructured => upwardBody != null;

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

  bool get hasOutwardPrompt => outwardPrompt != null;

  /// The Upward teaching: the structured section, or the legacy body.
  String? get upwardText => upwardBody ?? body;

  /// Prompts for the inline Inward reflection: the structured questions,
  /// falling back to the legacy discussion questions.
  List<String> get inwardPrompts =>
      inwardQuestions.isNotEmpty ? inwardQuestions : discussionQuestions;

  /// The Outward section text: the structured body, then the 0018 prompt,
  /// then the legacy activity field.
  String? get outwardText => outwardBody ?? outwardPrompt ?? activity;

  /// The line shown under the scripture block, e.g. "Hebrews 6:19 (WEB)".
  String get attribution => _attribute(scriptureReference, translation);

  /// The Go Deeper passage label, e.g. "Joshua 1:1-9 (NIV)". Uses
  /// [deeperTranslation] when the passage is quoted from a different version.
  String? get deeperAttribution => deeperReference == null
      ? null
      : _attribute(deeperReference!, deeperTranslation ?? translation);

  /// "This week: Courage · Day 2", or null for legacy rows.
  String? get themeLabel {
    final title = theme?.title;
    if (title == null || title.isEmpty) return null;
    return dayNumber == null ? title : '$title · Day $dayNumber';
  }
}

String _attribute(String reference, String translation) =>
    translation.trim().isEmpty ? reference : '$reference ($translation)';

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

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

import 'devotional_audience.dart';

/// A row of `public.devotional_themes`: the week-long theme a run of daily
/// devotionals shares (e.g. "Courage").
class DevotionalTheme {
  const DevotionalTheme({
    required this.id,
    required this.audience,
    required this.title,
    required this.startsOn,
    this.summary,
  });

  factory DevotionalTheme.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as String?)?.trim();
    return DevotionalTheme(
      id: json['id'] as String,
      audience: DevotionalAudience.fromWire(json['audience'] as String?),
      title: json['title'] as String? ?? '',
      startsOn: DateTime.tryParse(json['starts_on'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      summary: (summary == null || summary.isEmpty) ? null : summary,
    );
  }

  final String id;
  final DevotionalAudience audience;
  final String title;
  final String? summary;

  /// The date of day 1. A bare Postgres `date`, parsed to local midnight.
  final DateTime startsOn;
}

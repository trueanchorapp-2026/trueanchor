/// Mirrors the `public.devotional_audience` Postgres enum: who a devotional
/// is written for.
///
/// [wire] must stay byte-identical to the SQL enum labels.
enum DevotionalAudience {
  youth('youth'),
  adult('adult');

  const DevotionalAudience(this.wire);

  final String wire;

  /// Unknown or missing values read as youth — the audience every legacy row
  /// was written for, and the one every reader can fall back to.
  static DevotionalAudience fromWire(String? value) =>
      DevotionalAudience.values.firstWhere(
        (audience) => audience.wire == value,
        orElse: () => DevotionalAudience.youth,
      );
}

import 'devotional.dart';
import 'devotional_audience.dart';

abstract interface class DevotionalRepository {
  /// The devotional to show for [date] to a reader who prefers [audience].
  ///
  /// Returns the most recent devotional published on or before [date] for
  /// [audience] or youth, preferring [audience] when both exist for the same
  /// date (see `pickForAudience`). A gap in the content calendar leaves
  /// yesterday's reading on screen rather than an empty page. Null only when
  /// nothing has been published on or before [date] at all.
  ///
  /// Backed by `devotionals_select`, which is `using (true)`: every signed-in
  /// user reads the same global content.
  Future<Devotional?> fetchForDate(
    DateTime date, {
    DevotionalAudience audience = DevotionalAudience.youth,
  });

  /// Past devotionals in reverse chronological order, one per date, for the
  /// history view.
  Future<List<Devotional>> fetchHistory({
    DevotionalAudience audience = DevotionalAudience.youth,
    int limit = 30,
  });
}

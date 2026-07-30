import 'devotional.dart';

abstract interface class DevotionalRepository {
  /// The devotional to show for [date].
  ///
  /// Returns the row published for that exact date when one exists, otherwise
  /// the most recent devotional published before it — a gap in the content
  /// calendar should leave yesterday's reading on screen, not an empty page.
  /// Null only when nothing has been published on or before [date] at all.
  ///
  /// Backed by `devotionals_select`, which is `using (true)`: every signed-in
  /// user reads the same global content.
  Future<Devotional?> fetchForDate(DateTime date);
}

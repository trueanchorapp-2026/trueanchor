import 'weekly_summary.dart';
import 'youth_engagement.dart';

abstract interface class EngagementRepository {
  /// Every youth in the caller's church with their devotional engagement.
  ///
  /// Always an RPC: `youth_engagement_overview()` aggregates across the church
  /// in one pass, and its role test lives inside the function rather than in a
  /// policy. Raises `NOT_AUTHORIZED` for anyone but a youth pastor or app
  /// admin, so callers should gate on `canViewEngagementDashboard` first.
  ///
  /// [asOf] exists for the same reason the SQL parameter does: so a screen can
  /// be reasoned about against a fixed date rather than the wall clock.
  Future<List<YouthEngagement>> fetchOverview({DateTime? asOf});

  /// One profile's seven-day counts.
  ///
  /// Also an RPC, and for a sharper reason: `journal_entries` reads are gated
  /// by `entry_visibility`, so counting from the client would undercount a
  /// youth who keeps entries private and would move whenever they changed a
  /// sharing setting. `youth_weekly_summary()` counts every row and returns no
  /// content, with its own check for self / same-family parent / same-church
  /// youth pastor / app admin. Raises `NOT_AUTHORIZED` for anyone else.
  Future<WeeklySummary> fetchWeeklySummary(String profileId, {DateTime? asOf});
}

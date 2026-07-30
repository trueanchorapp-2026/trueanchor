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
}

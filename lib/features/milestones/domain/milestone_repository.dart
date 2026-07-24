import 'milestone.dart';

abstract interface class MilestoneRepository {
  /// Every milestone the signed-in user may read. RLS decides scope: a youth
  /// sees their own, a parent their family's, staff the whole church.
  Future<List<Milestone>> fetchVisible();

  Future<Milestone> create({
    required String profileId,
    required MilestoneType milestoneType,
    required String? title,
    required String? note,
    required DateTime achievedOn,
  });

  Future<void> delete(String id);
}

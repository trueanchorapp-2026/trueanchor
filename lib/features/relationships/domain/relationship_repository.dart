import '../../../core/domain/entry_visibility.dart';
import 'relationship.dart';
import 'relationship_interaction.dart';

abstract interface class RelationshipRepository {
  /// Everything the signed-in user is allowed to see.
  ///
  /// There is no filter here on purpose: RLS decides what comes back. A youth
  /// sees their own; a parent additionally sees what the youth in their
  /// household shared with adults; a pastor sees only what was shared with
  /// pastors. The client never gets rows it should not have, so it never has
  /// to hide any.
  Future<List<Relationship>> fetchVisible();
  Future<Relationship> create({
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  });
  Future<Relationship> update({
    required String id,
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  });
  Future<void> delete(String id);

  Future<List<RelationshipInteraction>> fetchInteractions(
      String relationshipId);
  Future<RelationshipInteraction> addInteraction({
    required String relationshipId,
    required InteractionType interactionType,
    String? note,
    DateTime? occurredOn,
  });
  Future<void> deleteInteraction(String id);
}

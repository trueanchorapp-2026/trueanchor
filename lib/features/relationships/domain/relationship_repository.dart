import 'relationship.dart';
import 'relationship_interaction.dart';

abstract interface class RelationshipRepository {
  Future<List<Relationship>> fetchVisible();
  Future<Relationship> create({
    required String name,
    String? context,
    String? nextStep,
  });
  Future<Relationship> update({
    required String id,
    required String name,
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

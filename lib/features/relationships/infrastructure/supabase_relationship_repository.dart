import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/domain/entry_visibility.dart';
import '../../../core/error/app_exception.dart';
import '../domain/relationship.dart';
import '../domain/relationship_interaction.dart';
import '../domain/relationship_repository.dart';

class SupabaseRelationshipRepository implements RelationshipRepository {
  const SupabaseRelationshipRepository(this._client);

  final SupabaseClient _client;

  /// The owner's name comes along because a parent with two teenagers cannot
  /// otherwise tell whose relationship they are reading. Safe under
  /// `profiles_select_family` / `profiles_select_staff` — anyone allowed the
  /// row is already allowed the name.
  static const _selectWithOwner =
      '*, owner:profiles!owner_id(first_name, last_name)';

  @override
  Future<List<Relationship>> fetchVisible() async {
    try {
      final rows = await _client
          .from('relationships')
          .select(_selectWithOwner)
          .order('updated_at', ascending: false);
      return rows.map(Relationship.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Relationship> create({
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  }) async {
    try {
      final row = await _client
          .from('relationships')
          .insert(Relationship.toInsertJson(
            name: name,
            visibility: visibility,
            context: context,
            nextStep: nextStep,
          ))
          .select(_selectWithOwner)
          .single();
      return Relationship.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<Relationship> update({
    required String id,
    required String name,
    required EntryVisibility visibility,
    String? context,
    String? nextStep,
  }) async {
    try {
      final row = await _client
          .from('relationships')
          .update(Relationship.toUpdateJson(
            name: name,
            visibility: visibility,
            context: context,
            nextStep: nextStep,
          ))
          .eq('id', id)
          .select(_selectWithOwner)
          .single();
      return Relationship.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _client.from('relationships').delete().eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<List<RelationshipInteraction>> fetchInteractions(
      String relationshipId) async {
    try {
      final rows = await _client
          .from('relationship_interactions')
          .select()
          .eq('relationship_id', relationshipId)
          .order('occurred_on', ascending: false);
      return rows.map(RelationshipInteraction.fromJson).toList();
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<RelationshipInteraction> addInteraction({
    required String relationshipId,
    required InteractionType interactionType,
    String? note,
    DateTime? occurredOn,
  }) async {
    try {
      final row = await _client
          .from('relationship_interactions')
          .insert(RelationshipInteraction.toInsertJson(
            relationshipId: relationshipId,
            interactionType: interactionType,
            note: note,
            occurredOn: occurredOn,
          ))
          .select()
          .single();
      return RelationshipInteraction.fromJson(row);
    } catch (error) {
      throw mapError(error);
    }
  }

  @override
  Future<void> deleteInteraction(String id) async {
    try {
      await _client
          .from('relationship_interactions')
          .delete()
          .eq('id', id);
    } catch (error) {
      throw mapError(error);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/relationship.dart';
import '../domain/relationship_interaction.dart';
import '../domain/relationship_repository.dart';
import '../infrastructure/supabase_relationship_repository.dart';

final relationshipRepositoryProvider = Provider<RelationshipRepository>(
  (ref) =>
      SupabaseRelationshipRepository(ref.watch(supabaseClientProvider)),
);

class RelationshipList extends AsyncNotifier<List<Relationship>> {
  @override
  Future<List<Relationship>> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(relationshipRepositoryProvider).fetchVisible();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(relationshipRepositoryProvider).fetchVisible(),
    );
  }

  Future<void> add({
    required String name,
    String? context,
    String? nextStep,
  }) async {
    final created = await ref.read(relationshipRepositoryProvider).create(
          name: name,
          context: context,
          nextStep: nextStep,
        );
    final current = state.value ?? const <Relationship>[];
    state = AsyncData([created, ...current]);
  }

  Future<void> edit({
    required String id,
    required String name,
    String? context,
    String? nextStep,
  }) async {
    final saved = await ref.read(relationshipRepositoryProvider).update(
          id: id,
          name: name,
          context: context,
          nextStep: nextStep,
        );
    final current = state.value ?? const <Relationship>[];
    state = AsyncData([
      for (final r in current)
        if (r.id == saved.id) saved else r,
    ]);
  }

  Future<void> remove(String id) async {
    await ref.read(relationshipRepositoryProvider).delete(id);
    final current = state.value ?? const <Relationship>[];
    state = AsyncData(current.where((r) => r.id != id).toList());
  }
}

final relationshipListProvider =
    AsyncNotifierProvider<RelationshipList, List<Relationship>>(
        RelationshipList.new);

class RelationshipInteractions
    extends AsyncNotifier<List<RelationshipInteraction>> {
  RelationshipInteractions(this.relationshipId);

  final String relationshipId;

  @override
  Future<List<RelationshipInteraction>> build() {
    ref.watch(currentUserIdProvider);
    return ref
        .watch(relationshipRepositoryProvider)
        .fetchInteractions(relationshipId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref
          .read(relationshipRepositoryProvider)
          .fetchInteractions(relationshipId),
    );
  }

  Future<void> add({
    required InteractionType interactionType,
    String? note,
    DateTime? occurredOn,
  }) async {
    final created =
        await ref.read(relationshipRepositoryProvider).addInteraction(
              relationshipId: relationshipId,
              interactionType: interactionType,
              note: note,
              occurredOn: occurredOn,
            );
    final current = state.value ?? const <RelationshipInteraction>[];
    state = AsyncData([created, ...current]);
  }

  Future<void> remove(String id) async {
    await ref.read(relationshipRepositoryProvider).deleteInteraction(id);
    final current = state.value ?? const <RelationshipInteraction>[];
    state = AsyncData(current.where((i) => i.id != id).toList());
  }
}

final relationshipInteractionsProvider = AsyncNotifierProvider.family<
    RelationshipInteractions, List<RelationshipInteraction>, String>(
  RelationshipInteractions.new,
);

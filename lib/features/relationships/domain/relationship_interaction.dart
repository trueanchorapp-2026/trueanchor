import 'package:flutter/material.dart';

enum InteractionType {
  hangout('hangout', 'Hangout', Icons.people_outline),
  invited('invited', 'Invited', Icons.person_add_outlined),
  prayer('prayer', 'Prayer', Icons.favorite_outline),
  encouragement('encouragement', 'Encouragement', Icons.thumb_up_outlined),
  service('service', 'Service', Icons.volunteer_activism_outlined),
  other('other', 'Other', Icons.more_horiz);

  const InteractionType(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static InteractionType fromWire(String value) =>
      InteractionType.values.firstWhere(
        (type) => type.wire == value,
        orElse: () => throw ArgumentError('Unknown interaction_type: $value'),
      );
}

class RelationshipInteraction {
  const RelationshipInteraction({
    required this.id,
    required this.relationshipId,
    required this.interactionType,
    required this.occurredOn,
    required this.createdAt,
    this.note,
  });

  factory RelationshipInteraction.fromJson(Map<String, dynamic> json) {
    return RelationshipInteraction(
      id: json['id'] as String,
      relationshipId: json['relationship_id'] as String,
      interactionType:
          InteractionType.fromWire(json['interaction_type'] as String),
      note: json['note'] as String?,
      occurredOn:
          DateTime.tryParse(json['occurred_on'] as String? ?? '') ??
              DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  final String id;
  final String relationshipId;
  final InteractionType interactionType;
  final String? note;
  final DateTime occurredOn;
  final DateTime createdAt;

  static Map<String, dynamic> toInsertJson({
    required String relationshipId,
    required InteractionType interactionType,
    String? note,
    DateTime? occurredOn,
  }) =>
      {
        'relationship_id': relationshipId,
        'interaction_type': interactionType.wire,
        'note': _blankToNull(note),
        if (occurredOn != null) 'occurred_on': _formatDate(occurredOn),
      };
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

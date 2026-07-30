import 'package:flutter/material.dart';

/// Mirrors the `public.milestone_type` Postgres enum.
///
/// [wire] must stay byte-identical to the SQL enum labels — it is what gets
/// written to and read from the database.
enum MilestoneType {
  acceptedChrist('accepted_christ', 'Accepted Christ', Icons.favorite_outline),
  baptized('baptized', 'Baptized', Icons.water_drop_outlined),
  scriptureMemory('scripture_memory', 'Scripture memory', Icons.menu_book_outlined),
  devotionStreak('devotion_streak', 'Devotion consistency', Icons.local_fire_department_outlined),
  service('service', 'Ministry / service', Icons.volunteer_activism_outlined),
  other('other', 'Other', Icons.star_outline);

  const MilestoneType(this.wire, this.label, this.icon);

  final String wire;
  final String label;
  final IconData icon;

  static MilestoneType fromWire(String value) => MilestoneType.values.firstWhere(
        (type) => type.wire == value,
        orElse: () => throw ArgumentError('Unknown milestone_type: $value'),
      );
}

/// A row of `public.milestones`: an achievement recorded for a youth.
class Milestone {
  const Milestone({
    required this.id,
    required this.profileId,
    required this.milestoneType,
    required this.achievedOn,
    required this.createdAt,
    this.title,
    this.note,
    this.subjectName,
    this.autoLogged = false,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    return Milestone(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      milestoneType: MilestoneType.fromWire(json['milestone_type'] as String),
      title: json['title'] as String?,
      note: json['note'] as String?,
      achievedOn: DateTime.tryParse(json['achieved_on'] as String? ?? '') ??
          DateTime.now(),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      subjectName: subject is Map<String, dynamic> ? _nameOf(subject) : null,
      autoLogged: json['auto_logged'] as bool? ?? false,
    );
  }

  final String id;
  final String profileId;
  final MilestoneType milestoneType;
  final String? title;
  final String? note;
  final DateTime achievedOn;
  final DateTime createdAt;

  /// The subject's name, when the query joined it in. Absent for a youth
  /// viewing their own list (where it would just be their own name).
  final String? subjectName;

  /// Recorded by the database rather than typed by a person: baptism, mirrored
  /// from the profile, and devotion streaks, mirrored from daily progress.
  /// Shown so nobody wonders where the row came from; the database keeps these
  /// in step on its own.
  final bool autoLogged;

  /// The line shown as the card heading: a custom title if given, otherwise
  /// the milestone type's own label.
  String get displayTitle {
    final trimmed = title?.trim();
    return (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : milestoneType.label;
  }

  /// profile_id is the only tenancy the client sends: a trigger stamps
  /// church_id, family_id and recorded_by from the subject and the caller.
  static Map<String, dynamic> toInsertJson({
    required String profileId,
    required MilestoneType milestoneType,
    required String? title,
    required String? note,
    required DateTime achievedOn,
  }) =>
      {
        'profile_id': profileId,
        'milestone_type': milestoneType.wire,
        'title': _blankToNull(title),
        'note': _blankToNull(note),
        'achieved_on': _formatDate(achievedOn),
      };
}

String? _nameOf(Map<String, dynamic> subject) {
  final name = [
    subject['first_name'] as String? ?? '',
    subject['last_name'] as String? ?? '',
  ].where((part) => part.trim().isNotEmpty).join(' ').trim();
  return name.isEmpty ? null : name;
}

String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Postgres `date` columns want a bare yyyy-MM-dd.
String _formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

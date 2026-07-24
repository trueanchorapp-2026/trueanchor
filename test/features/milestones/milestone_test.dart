import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/milestones/domain/milestone.dart';

Map<String, dynamic> _row({
  String milestoneType = 'baptized',
  String? title,
  String? note = 'A joyful day.',
  Object? subject = const {'first_name': 'Sam', 'last_name': 'Rivers'},
}) =>
    {
      'id': 'milestone-1',
      'profile_id': 'youth-1',
      'milestone_type': milestoneType,
      'title': title,
      'note': note,
      'achieved_on': '2026-07-19',
      'created_at': '2026-07-20T14:30:00Z',
      'subject': ?subject,
    };

void main() {
  group('wire values match the Postgres enum', () {
    // These strings are a contract with the database: drift and inserts fail.
    test('every label maps to its SQL enum label', () {
      expect(MilestoneType.acceptedChrist.wire, 'accepted_christ');
      expect(MilestoneType.baptized.wire, 'baptized');
      expect(MilestoneType.scriptureMemory.wire, 'scripture_memory');
      expect(MilestoneType.devotionStreak.wire, 'devotion_streak');
      expect(MilestoneType.service.wire, 'service');
      expect(MilestoneType.other.wire, 'other');
    });

    test('round-trips through fromWire', () {
      for (final type in MilestoneType.values) {
        expect(MilestoneType.fromWire(type.wire), type);
      }
    });

    test('an unrecognised type throws rather than defaulting', () {
      expect(() => MilestoneType.fromWire('married'), throwsArgumentError);
    });
  });

  group('Milestone.fromJson', () {
    test('maps the row and the joined subject name', () {
      final milestone = Milestone.fromJson(_row());

      expect(milestone.id, 'milestone-1');
      expect(milestone.profileId, 'youth-1');
      expect(milestone.milestoneType, MilestoneType.baptized);
      expect(milestone.note, 'A joyful day.');
      expect(milestone.subjectName, 'Sam Rivers');
    });

    test('reads auto_logged, defaulting to hand-recorded when absent', () {
      expect(Milestone.fromJson(_row()).autoLogged, isFalse);
      expect(
        Milestone.fromJson({..._row(), 'auto_logged': true}).autoLogged,
        isTrue,
      );
    });

    test('parses achieved_on as a bare date', () {
      final milestone = Milestone.fromJson(_row());
      expect(milestone.achievedOn.year, 2026);
      expect(milestone.achievedOn.month, 7);
      expect(milestone.achievedOn.day, 19);
    });

    test('leaves subjectName null when the query did not join it', () {
      final milestone = Milestone.fromJson(_row(subject: null));
      expect(milestone.subjectName, isNull);
    });

    test('leaves subjectName null when the join carried no name', () {
      final milestone = Milestone.fromJson(
        _row(subject: const {'first_name': '', 'last_name': ''}),
      );
      expect(milestone.subjectName, isNull);
    });
  });

  group('displayTitle', () {
    test('prefers a custom title', () {
      final milestone = Milestone.fromJson(_row(title: 'First communion'));
      expect(milestone.displayTitle, 'First communion');
    });

    test('falls back to the type label when untitled', () {
      expect(Milestone.fromJson(_row()).displayTitle, 'Baptized');
    });

    test('falls back when the title is only whitespace', () {
      final milestone = Milestone.fromJson(_row(title: '   '));
      expect(milestone.displayTitle, 'Baptized');
    });
  });

  group('toInsertJson', () {
    Map<String, dynamic> insert({
      String? title = '  Baptized at camp  ',
      String? note = '   ',
    }) =>
        Milestone.toInsertJson(
          profileId: 'youth-1',
          milestoneType: MilestoneType.baptized,
          title: title,
          note: note,
          achievedOn: DateTime(2026, 7, 9),
        );

    test('sends only profile_id as tenancy — a trigger stamps the rest', () {
      final json = insert();
      expect(json.containsKey('church_id'), isFalse);
      expect(json.containsKey('family_id'), isFalse);
      expect(json.containsKey('recorded_by'), isFalse);
      expect(json['profile_id'], 'youth-1');
    });

    test('writes the enum wire value', () {
      expect(insert()['milestone_type'], 'baptized');
    });

    test('formats achieved_on as a zero-padded yyyy-MM-dd', () {
      expect(insert()['achieved_on'], '2026-07-09');
    });

    test('trims the title and collapses blanks to null', () {
      final json = insert();
      expect(json['title'], 'Baptized at camp');
      expect(json['note'], isNull);
    });
  });
}

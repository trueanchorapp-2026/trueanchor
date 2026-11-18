import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/core/domain/entry_visibility.dart';
import 'package:trueanchor/features/relationships/domain/parent_relationship_sharing.dart';

void main() {
  group('ParentRelationshipSharing', () {
    test('a new parent relationship starts private', () {
      expect(ParentRelationshipSharing.defaultSharesWithFamily, isFalse);
      expect(
        ParentRelationshipSharing.resolve(
          withFamily: ParentRelationshipSharing.defaultSharesWithFamily,
        ),
        EntryVisibility.private,
      );
    });

    test('sharing reaches the whole family', () {
      expect(
        ParentRelationshipSharing.resolve(withFamily: true),
        EntryVisibility.family,
      );
    });

    test('only family-wide rungs read back as shared', () {
      expect(
        ParentRelationshipSharing.sharesWithFamily(EntryVisibility.family),
        isTrue,
      );
      expect(
        ParentRelationshipSharing.sharesWithFamily(
            EntryVisibility.familyPastor),
        isTrue,
      );
      for (final rung in [
        EntryVisibility.private,
        EntryVisibility.parents,
        EntryVisibility.parentsPastor,
      ]) {
        expect(ParentRelationshipSharing.sharesWithFamily(rung), isFalse);
      }
    });

    test('round-trips through resolve', () {
      for (final shared in [true, false]) {
        expect(
          ParentRelationshipSharing.sharesWithFamily(
            ParentRelationshipSharing.resolve(withFamily: shared),
          ),
          shared,
        );
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/discussion_query.dart';

void main() {
  group('DiscussionQuery', () {
    test('defaults to unfiltered, newest first', () {
      const query = DiscussionQuery();
      expect(query.isFiltered, isFalse);
      expect(query.sort, DiscussionSort.newest);
    });

    test('toggleTag adds then removes a tag', () {
      final added = const DiscussionQuery().toggleTag('t1');
      expect(added.tagIds, {'t1'});
      expect(added.isFiltered, isTrue);
      expect(added.toggleTag('t1').tagIds, isEmpty);
    });

    test('whitespace-only text is not a filter; sort alone is not either', () {
      expect(const DiscussionQuery(text: '   ').isFiltered, isFalse);
      expect(
        const DiscussionQuery(sort: DiscussionSort.oldest).isFiltered,
        isFalse,
      );
      expect(const DiscussionQuery(text: 'board').isFiltered, isTrue);
    });

    test('cleared drops tags and text but keeps the sort', () {
      const query = DiscussionQuery(
        tagIds: {'t1'},
        text: 'x',
        sort: DiscussionSort.mostReplies,
      );
      expect(
        query.cleared(),
        const DiscussionQuery(sort: DiscussionSort.mostReplies),
      );
    });

    test('equality ignores tag order', () {
      expect(
        const DiscussionQuery(tagIds: {'a', 'b'}),
        const DiscussionQuery(tagIds: {'b', 'a'}),
      );
      expect(
        const DiscussionQuery(tagIds: {'a', 'b'}).hashCode,
        const DiscussionQuery(tagIds: {'b', 'a'}).hashCode,
      );
    });

    test('toRpcParams sends nulls for empty filters', () {
      expect(const DiscussionQuery(text: '  ').toRpcParams('c1'), {
        'p_community_id': 'c1',
        'p_tag_ids': null,
        'p_query': null,
        'p_sort': 'newest',
      });
    });

    test('toRpcParams trims text, sorts tag ids, maps sort', () {
      const query = DiscussionQuery(
        tagIds: {'b', 'a'},
        text: '  school board ',
        sort: DiscussionSort.recentActivity,
      );
      expect(query.toRpcParams('c1'), {
        'p_community_id': 'c1',
        'p_tag_ids': ['a', 'b'],
        'p_query': 'school board',
        'p_sort': 'activity',
      });
    });

    test('every sort has a distinct wire value the RPC understands', () {
      expect(
        DiscussionSort.values.map((s) => s.wireValue),
        ['newest', 'activity', 'replies', 'oldest'],
      );
    });
  });
}

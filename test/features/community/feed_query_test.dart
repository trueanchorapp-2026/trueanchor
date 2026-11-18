import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/feed_query.dart';

void main() {
  group('FeedQuery', () {
    test('defaults to unfiltered, newest first', () {
      const query = FeedQuery();
      expect(query.isFiltered, isFalse);
      expect(query.sort, FeedSort.newest);
    });

    test('toggleTag adds then removes a tag', () {
      final added = const FeedQuery().toggleTag('t1');
      expect(added.tagIds, {'t1'});
      expect(added.isFiltered, isTrue);
      expect(added.toggleTag('t1').tagIds, isEmpty);
    });

    test('whitespace-only text is not a filter; sort alone is not either', () {
      expect(const FeedQuery(text: '   ').isFiltered, isFalse);
      expect(
        const FeedQuery(sort: FeedSort.oldest).isFiltered,
        isFalse,
      );
      expect(const FeedQuery(text: 'board').isFiltered, isTrue);
    });

    test('cleared drops tags and text but keeps the sort', () {
      const query = FeedQuery(
        tagIds: {'t1'},
        text: 'x',
        sort: FeedSort.mostReplies,
      );
      expect(
        query.cleared(),
        const FeedQuery(sort: FeedSort.mostReplies),
      );
    });

    test('equality ignores tag order', () {
      expect(
        const FeedQuery(tagIds: {'a', 'b'}),
        const FeedQuery(tagIds: {'b', 'a'}),
      );
      expect(
        const FeedQuery(tagIds: {'a', 'b'}).hashCode,
        const FeedQuery(tagIds: {'b', 'a'}).hashCode,
      );
    });

    test('toRpcParams sends nulls for empty filters', () {
      expect(const FeedQuery(text: '  ').toRpcParams('c1'), {
        'p_community_id': 'c1',
        'p_tag_ids': null,
        'p_query': null,
        'p_sort': 'newest',
      });
    });

    test('toRpcParams trims text, sorts tag ids, maps sort', () {
      const query = FeedQuery(
        tagIds: {'b', 'a'},
        text: '  school board ',
        sort: FeedSort.recentActivity,
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
        FeedSort.values.map((s) => s.wireValue),
        ['newest', 'activity', 'replies', 'top', 'oldest', 'title'],
      );
    });

    test('each feed offers only its own sorts', () {
      expect(FeedSort.discussionSorts, isNot(contains(FeedSort.title)));
      expect(FeedSort.discussionSorts, contains(FeedSort.top));
      expect(FeedSort.newsSorts,
          [FeedSort.newest, FeedSort.top, FeedSort.oldest]);
      expect(FeedSort.resourceSorts, [...FeedSort.newsSorts, FeedSort.title]);
    });

    test('a new post goes first only in an unfiltered recent-first feed', () {
      expect(const FeedQuery().newPostGoesFirst, isTrue);
      expect(const FeedQuery(sort: FeedSort.recentActivity).newPostGoesFirst,
          isTrue);
      expect(const FeedQuery(sort: FeedSort.top).newPostGoesFirst, isFalse);
      expect(const FeedQuery(sort: FeedSort.title).newPostGoesFirst, isFalse);
      expect(const FeedQuery(tagIds: {'t1'}).newPostGoesFirst, isFalse);
    });
  });
}

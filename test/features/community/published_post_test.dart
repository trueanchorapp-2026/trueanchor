import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/published_post.dart';
import 'package:trueanchor/features/community/domain/vote.dart';

void main() {
  group('PublishedPost.fromJson', () {
    test('reads a search-RPC row', () {
      final post = PublishedPost.fromJson(PublishedKind.news, {
        'id': 'n1',
        'community_id': 'c1',
        'author_id': 'u1',
        'title': 'Board vote',
        'body': 'Details',
        'link_url': 'https://example.org',
        'author_first_name': 'Ana',
        'author_last_name': 'Diaz',
        'tag_ids': ['t1', 't2'],
        'upvotes': 3,
        'downvotes': 1,
        'my_vote': 1,
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
      });
      expect(post.kind, PublishedKind.news);
      expect(post.linkUrl, 'https://example.org');
      expect(post.authorName, 'Ana Diaz');
      expect(post.tagIds, ['t1', 't2']);
      expect(post.votes, const VoteTally(upvotes: 3, downvotes: 1, myVote: 1));
    });

    test('reads a table row with embeds; blank link is no link', () {
      final post = PublishedPost.fromJson(PublishedKind.resource, {
        'id': 'r1',
        'community_id': 'c1',
        'title': 'Guide',
        'body': null,
        'link_url': '  ',
        'author': {'first_name': 'Ana', 'last_name': null},
        'tags': [
          {'tag_id': 't1'},
        ],
        'my_votes': [
          {'value': -1},
        ],
        'downvotes': 1,
      });
      expect(post.body, '');
      expect(post.linkUrl, isNull);
      expect(post.authorName, 'Ana');
      expect(post.votes.myVote, -1);
    });
  });

  group('links', () {
    test('normalizeLink trims and adds https when no scheme', () {
      expect(PublishedPost.normalizeLink('  example.org/a '),
          'https://example.org/a');
      expect(PublishedPost.normalizeLink('http://x.org'), 'http://x.org');
      expect(PublishedPost.normalizeLink('   '), isNull);
      expect(PublishedPost.normalizeLink(null), isNull);
    });

    test('isValidLink accepts empty and web links only', () {
      expect(PublishedPost.isValidLink(''), isTrue);
      expect(PublishedPost.isValidLink('example.org'), isTrue);
      expect(PublishedPost.isValidLink('https://a.b/c?d=1'), isTrue);
      expect(PublishedPost.isValidLink('ftp://a.org'), isFalse);
      expect(PublishedPost.isValidLink('not a link'), isFalse);
      expect(PublishedPost.isValidLink('localhost'), isFalse);
    });

    test('toWriteJson trims and normalizes', () {
      expect(
        PublishedPost.toWriteJson(
          title: ' T ',
          body: ' B ',
          linkUrl: 'example.org',
        ),
        {'title': 'T', 'body': 'B', 'link_url': 'https://example.org'},
      );
      expect(
        PublishedPost.toWriteJson(title: 'T', body: '')['link_url'],
        isNull,
      );
    });
  });

  test('only news requires a body', () {
    expect(PublishedKind.news.requiresBody, isTrue);
    expect(PublishedKind.resource.requiresBody, isFalse);
  });
}

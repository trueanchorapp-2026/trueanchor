import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/community_discussion.dart';

Map<String, dynamic> _row({Object? imageUrls}) => {
      'id': 'd1',
      'community_id': 'c1',
      'discussion_id': 'd1',
      'author_id': 'u1',
      'title': 'School board meeting',
      'body': 'Who is going Tuesday?',
      'created_at': '2026-10-01T12:00:00Z',
      'updated_at': '2026-10-01T12:00:00Z',
      'image_urls': ?imageUrls,
    };

void main() {
  group('CommunityDiscussion images', () {
    test('reads image_urls in order, and empty when absent', () {
      expect(
        CommunityDiscussion.fromJson(
          _row(imageUrls: ['https://x/a', 'https://x/b']),
        ).imageUrls,
        ['https://x/a', 'https://x/b'],
      );
      expect(CommunityDiscussion.fromJson(_row()).imageUrls, isEmpty);
    });

    test('insert payload carries image_urls', () {
      expect(
        CommunityDiscussion.toInsertJson(
          communityId: 'c1',
          authorId: 'u1',
          title: 'Title',
          body: 'Body',
          imageUrls: ['https://x/a'],
        )['image_urls'],
        ['https://x/a'],
      );
    });
  });

  group('DiscussionReply images', () {
    test('reads image_urls, and empty when absent', () {
      expect(
        DiscussionReply.fromJson(_row(imageUrls: ['https://x/a'])).imageUrls,
        ['https://x/a'],
      );
      expect(DiscussionReply.fromJson(_row()).imageUrls, isEmpty);
    });

    test('insert payload carries image_urls, defaulting to none', () {
      expect(
        DiscussionReply.toInsertJson(
          discussionId: 'd1',
          authorId: 'u1',
          body: 'Nice',
          imageUrls: ['https://x/a'],
        )['image_urls'],
        ['https://x/a'],
      );
      expect(
        DiscussionReply.toInsertJson(
          discussionId: 'd1',
          authorId: 'u1',
          body: 'Nice',
        )['image_urls'],
        isEmpty,
      );
    });
  });
}

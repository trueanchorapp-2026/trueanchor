import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/community_discussion.dart';

Map<String, dynamic> _row({Object? imageUrl}) => {
      'id': 'd1',
      'community_id': 'c1',
      'author_id': 'u1',
      'title': 'School board meeting',
      'body': 'Who is going Tuesday?',
      'created_at': '2026-10-01T12:00:00Z',
      'updated_at': '2026-10-01T12:00:00Z',
      'image_url': ?imageUrl,
    };

void main() {
  group('CommunityDiscussion image', () {
    test('reads image_url when present and null when absent', () {
      expect(
        CommunityDiscussion.fromJson(_row(imageUrl: 'https://x/a.png'))
            .imageUrl,
        'https://x/a.png',
      );
      expect(CommunityDiscussion.fromJson(_row()).imageUrl, isNull);
    });

    test('insert payload carries image_url only when there is one', () {
      Map<String, dynamic> insert({String? imageUrl}) =>
          CommunityDiscussion.toInsertJson(
            communityId: 'c1',
            authorId: 'u1',
            title: 'Title',
            body: 'Body',
            imageUrl: imageUrl,
          );

      expect(insert(imageUrl: 'https://x/a.png')['image_url'],
          'https://x/a.png');
      expect(insert().containsKey('image_url'), isFalse);
    });

    test('maps known extensions to content types, case-insensitively', () {
      expect(CommunityDiscussion.imageContentTypeFor('a.PNG'), 'image/png');
      expect(CommunityDiscussion.imageContentTypeFor('a.jpeg'), 'image/jpeg');
      expect(CommunityDiscussion.imageContentTypeFor('a.webp'), 'image/webp');
    });

    test('falls back to JPEG for unknown or missing extensions', () {
      expect(CommunityDiscussion.imageContentTypeFor('a.heic'), 'image/jpeg');
      expect(CommunityDiscussion.imageContentTypeFor('noext'), 'image/jpeg');
    });

    test('strips path-unsafe characters from file names', () {
      expect(
        CommunityDiscussion.safeImageFileName('my photo/../x?.png'),
        'my_photo_.._x_.png',
      );
      expect(CommunityDiscussion.safeImageFileName(''), 'image');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:trueanchor/features/community/domain/discussion_image.dart';

void main() {
  group('DiscussionImages', () {
    test('caps attachments at five, matching the 0029 checks', () {
      expect(DiscussionImages.maxPerEntry, 5);
    });

    test('maps known extensions to content types, case-insensitively', () {
      expect(DiscussionImages.contentTypeFor('a.PNG'), 'image/png');
      expect(DiscussionImages.contentTypeFor('a.jpeg'), 'image/jpeg');
      expect(DiscussionImages.contentTypeFor('a.webp'), 'image/webp');
    });

    test('falls back to JPEG for unknown or missing extensions', () {
      expect(DiscussionImages.contentTypeFor('a.heic'), 'image/jpeg');
      expect(DiscussionImages.contentTypeFor('noext'), 'image/jpeg');
    });

    test('strips path-unsafe characters from file names', () {
      expect(
        DiscussionImages.safeFileName('my photo/../x?.png'),
        'my_photo_.._x_.png',
      );
      expect(DiscussionImages.safeFileName(''), 'image');
    });

    test('reads the image_urls column defensively', () {
      expect(DiscussionImages.urlsFromJson(['a', 'b']), ['a', 'b']);
      expect(DiscussionImages.urlsFromJson(null), isEmpty);
      expect(DiscussionImages.urlsFromJson(['a', null, 3]), ['a']);
    });
  });
}

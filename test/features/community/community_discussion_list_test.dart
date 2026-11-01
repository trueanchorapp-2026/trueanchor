import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/community/application/community_providers.dart';
import 'package:trueanchor/features/community/domain/community_discussion.dart';
import 'package:trueanchor/features/community/domain/community_repository.dart';
import 'package:trueanchor/features/community/domain/discussion_image.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

PendingImage _image(String name) =>
    PendingImage(fileName: name, bytes: Uint8List.fromList([1, 2, 3]));

CommunityDiscussion _discussion({List<String> imageUrls = const []}) =>
    CommunityDiscussion(
      id: 'd1',
      communityId: 'c1',
      authorId: 'u1',
      title: 'Title',
      body: 'Body',
      imageUrls: imageUrls,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

DiscussionReply _reply({List<String> imageUrls = const []}) => DiscussionReply(
      id: 'r1',
      discussionId: 'd1',
      authorId: 'u1',
      body: 'Reply',
      imageUrls: imageUrls,
      createdAt: DateTime(2026),
    );

void main() {
  late MockCommunityRepository repository;

  setUp(() {
    repository = MockCommunityRepository();
    when(() => repository.fetchMyMembership()).thenAnswer((_) async => null);
    when(() => repository.fetchReplies(any())).thenAnswer((_) async => []);
    // Each upload returns a URL named after its file, so order is checkable.
    when(() => repository.uploadDiscussionImage(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
        )).thenAnswer(
      (invocation) async =>
          'https://x/${invocation.namedArguments[#fileName]}',
    );
    when(() => repository.createDiscussion(
          communityId: any(named: 'communityId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          imageUrls: any(named: 'imageUrls'),
        )).thenAnswer(
      (invocation) async => _discussion(
        imageUrls: invocation.namedArguments[#imageUrls] as List<String>,
      ),
    );
    when(() => repository.createReply(
          discussionId: any(named: 'discussionId'),
          body: any(named: 'body'),
          imageUrls: any(named: 'imageUrls'),
        )).thenAnswer(
      (invocation) async => _reply(
        imageUrls: invocation.namedArguments[#imageUrls] as List<String>,
      ),
    );
  });

  ProviderContainer container() => ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          communityRepositoryProvider.overrideWithValue(repository),
        ],
      );

  void verifyNoUploads() => verifyNever(() => repository.uploadDiscussionImage(
        fileName: any(named: 'fileName'),
        bytes: any(named: 'bytes'),
      ));

  group('discussion posts', () {
    test('uploads every image and stores their URLs in pick order', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await c.read(communityDiscussionListProvider.notifier).add(
            communityId: 'c1',
            title: 'Title',
            body: 'Body',
            images: [_image('a.png'), _image('b.png'), _image('c.png')],
          );

      verify(() => repository.createDiscussion(
            communityId: 'c1',
            title: 'Title',
            body: 'Body',
            imageUrls: [
              'https://x/a.png',
              'https://x/b.png',
              'https://x/c.png',
            ],
          )).called(1);
      expect(
        c.read(communityDiscussionListProvider).value?.single.imageUrls,
        hasLength(3),
      );
    });

    test('skips uploading when no images were picked', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await c
          .read(communityDiscussionListProvider.notifier)
          .add(communityId: 'c1', title: 'Title', body: 'Body');

      verifyNoUploads();
      verify(() => repository.createDiscussion(
            communityId: 'c1',
            title: 'Title',
            body: 'Body',
            imageUrls: [],
          )).called(1);
    });

    test('rejects more than five images before uploading any', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await expectLater(
        c.read(communityDiscussionListProvider.notifier).add(
              communityId: 'c1',
              title: 'Title',
              body: 'Body',
              images: [for (var i = 0; i < 6; i++) _image('$i.png')],
            ),
        throwsArgumentError,
      );
      verifyNoUploads();
    });

    test('does not create the post if an upload fails', () async {
      when(() => repository.uploadDiscussionImage(
            fileName: any(named: 'fileName'),
            bytes: any(named: 'bytes'),
          )).thenThrow(Exception('storage down'));
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await expectLater(
        c.read(communityDiscussionListProvider.notifier).add(
              communityId: 'c1',
              title: 'Title',
              body: 'Body',
              images: [_image('a.png')],
            ),
        throwsException,
      );
      verifyNever(() => repository.createDiscussion(
            communityId: any(named: 'communityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            imageUrls: any(named: 'imageUrls'),
          ));
    });
  });

  group('replies', () {
    test('uploads reply images and attaches their URLs', () async {
      final c = container();
      await c.read(discussionRepliesProvider('d1').future);

      await c.read(discussionRepliesProvider('d1').notifier).add(
            body: 'Reply',
            images: [_image('a.png'), _image('b.png')],
          );

      verify(() => repository.createReply(
            discussionId: 'd1',
            body: 'Reply',
            imageUrls: ['https://x/a.png', 'https://x/b.png'],
          )).called(1);
      expect(
        c.read(discussionRepliesProvider('d1')).value?.single.imageUrls,
        ['https://x/a.png', 'https://x/b.png'],
      );
    });

    test('a text-only reply uploads nothing', () async {
      final c = container();
      await c.read(discussionRepliesProvider('d1').future);

      await c.read(discussionRepliesProvider('d1').notifier).add(body: 'Hi');

      verifyNoUploads();
    });

    test('rejects more than five reply images', () async {
      final c = container();
      await c.read(discussionRepliesProvider('d1').future);

      await expectLater(
        c.read(discussionRepliesProvider('d1').notifier).add(
              body: 'Reply',
              images: [for (var i = 0; i < 6; i++) _image('$i.png')],
            ),
        throwsArgumentError,
      );
      verifyNoUploads();
    });
  });
}

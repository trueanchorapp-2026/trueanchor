import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/community/application/community_providers.dart';
import 'package:trueanchor/features/community/domain/community_discussion.dart';
import 'package:trueanchor/features/community/domain/community_membership.dart';
import 'package:trueanchor/features/community/domain/community_repository.dart';
import 'package:trueanchor/features/community/domain/discussion_image.dart';
import 'package:trueanchor/features/community/domain/feed_query.dart';
import 'package:trueanchor/features/community/domain/published_post.dart';
import 'package:trueanchor/features/community/domain/vote.dart';
import 'package:trueanchor/features/profile/application/profile_providers.dart';
import 'package:trueanchor/features/profile/domain/profile.dart';
import 'package:trueanchor/features/profile/domain/user_role.dart';

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

CommunityMembership _membership() => CommunityMembership(
      id: 'm1',
      communityId: 'c1',
      familyId: 'f1',
      joinedBy: 'u1',
      joinedAt: DateTime(2026),
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
          tagIds: any(named: 'tagIds'),
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
            tagIds: any(named: 'tagIds'),
          ));
    });
  });

  group('tags and query', () {
    setUp(() {
      registerFallbackValue(const FeedQuery());
      when(() => repository.fetchMyMembership())
          .thenAnswer((_) async => _membership());
      when(() => repository.searchDiscussions(any(), any()))
          .thenAnswer((_) async => [_discussion()]);
      when(() => repository.setDiscussionTags(
            discussionId: any(named: 'discussionId'),
            tagIds: any(named: 'tagIds'),
          )).thenAnswer((_) async {});
    });

    test('passes chosen tags through to createDiscussion', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await c.read(communityDiscussionListProvider.notifier).add(
            communityId: 'c1',
            title: 'Title',
            body: 'Body',
            tagIds: ['t1', 't2'],
          );

      verify(() => repository.createDiscussion(
            communityId: 'c1',
            title: 'Title',
            body: 'Body',
            imageUrls: [],
            tagIds: ['t1', 't2'],
          )).called(1);
    });

    test('rejects more than three tags before creating anything', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await expectLater(
        c.read(communityDiscussionListProvider.notifier).add(
              communityId: 'c1',
              title: 'Title',
              body: 'Body',
              tagIds: ['t1', 't2', 't3', 't4'],
            ),
        throwsArgumentError,
      );
      verifyNever(() => repository.createDiscussion(
            communityId: any(named: 'communityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            imageUrls: any(named: 'imageUrls'),
            tagIds: any(named: 'tagIds'),
          ));
    });

    test('changing the query re-runs the search with it', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      c.read(discussionQueryProvider.notifier)
        ..toggleTag('t1')
        ..setSort(FeedSort.mostReplies);
      await c.read(communityDiscussionListProvider.future);

      verify(() => repository.searchDiscussions(
            'c1',
            const FeedQuery(
              tagIds: {'t1'},
              sort: FeedSort.mostReplies,
            ),
          )).called(1);
    });

    test('updateTags saves and updates the post in place', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await c
          .read(communityDiscussionListProvider.notifier)
          .updateTags(discussionId: 'd1', tagIds: ['t3']);

      verify(() => repository.setDiscussionTags(
            discussionId: 'd1',
            tagIds: ['t3'],
          )).called(1);
      expect(
        c.read(communityDiscussionListProvider).value?.single.tagIds,
        ['t3'],
      );
    });

    test('a new reply bumps the reply count in the list', () async {
      final c = container();
      await c.read(communityDiscussionListProvider.future);
      await c.read(discussionRepliesProvider('d1').future);

      await c.read(discussionRepliesProvider('d1').notifier).add(body: 'Hi');

      expect(
        c.read(communityDiscussionListProvider).value?.single.replyCount,
        1,
      );
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

  group('votes', () {
    setUp(() {
      registerFallbackValue(const FeedQuery());
      registerFallbackValue(VoteTarget.discussion);
      when(() => repository.fetchMyMembership())
          .thenAnswer((_) async => _membership());
      when(() => repository.searchDiscussions(any(), any()))
          .thenAnswer((_) async => [_discussion()]);
    });

    CommunityDiscussion listed(ProviderContainer c) =>
        c.read(communityDiscussionListProvider).value!.single;

    test('shows the vote at once, then the saved tally', () async {
      final saved = Completer<VoteTally>();
      when(() => repository.castVote(
            target: any(named: 'target'),
            itemId: any(named: 'itemId'),
            value: any(named: 'value'),
          )).thenAnswer((_) => saved.future);
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      final pending = c
          .read(communityDiscussionListProvider.notifier)
          .vote(listed(c), 1);
      expect(listed(c).votes, const VoteTally(upvotes: 1, myVote: 1));

      saved.complete(const VoteTally(upvotes: 5, myVote: 1));
      await pending;
      expect(listed(c).votes, const VoteTally(upvotes: 5, myVote: 1));
      verify(() => repository.castVote(
            target: VoteTarget.discussion,
            itemId: 'd1',
            value: 1,
          )).called(1);
    });

    test('rolls back and rethrows when the vote fails', () async {
      when(() => repository.castVote(
            target: any(named: 'target'),
            itemId: any(named: 'itemId'),
            value: any(named: 'value'),
          )).thenThrow(Exception('offline'));
      final c = container();
      await c.read(communityDiscussionListProvider.future);

      await expectLater(
        c.read(communityDiscussionListProvider.notifier).vote(listed(c), -1),
        throwsException,
      );
      expect(listed(c).votes, const VoteTally());
    });

    test('toggleHelpful marks a reply and keeps the server count', () async {
      when(() => repository.fetchReplies(any()))
          .thenAnswer((_) async => [_reply()]);
      when(() => repository.toggleReplyHelpful('r1'))
          .thenAnswer((_) async => (helpfulCount: 7, markedByMe: true));
      final c = container();
      await c.read(discussionRepliesProvider('d1').future);

      await c
          .read(discussionRepliesProvider('d1').notifier)
          .toggleHelpful('r1');

      final reply = c.read(discussionRepliesProvider('d1')).value!.single;
      expect((reply.helpfulCount, reply.markedHelpfulByMe), (7, true));
    });

    test('toggleHelpful rolls back on error', () async {
      when(() => repository.fetchReplies(any()))
          .thenAnswer((_) async => [_reply()]);
      when(() => repository.toggleReplyHelpful('r1'))
          .thenThrow(Exception('offline'));
      final c = container();
      await c.read(discussionRepliesProvider('d1').future);

      await expectLater(
        c.read(discussionRepliesProvider('d1').notifier).toggleHelpful('r1'),
        throwsException,
      );
      final reply = c.read(discussionRepliesProvider('d1')).value!.single;
      expect((reply.helpfulCount, reply.markedHelpfulByMe), (0, false));
    });
  });

  group('published posts', () {
    PublishedPost post({String id = 'n1', List<String> tagIds = const []}) =>
        PublishedPost(
          id: id,
          kind: PublishedKind.news,
          communityId: 'c1',
          title: 'News',
          body: 'Body',
          tagIds: tagIds,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

    setUp(() {
      registerFallbackValue(const FeedQuery());
      registerFallbackValue(PublishedKind.news);
      when(() => repository.fetchMyMembership())
          .thenAnswer((_) async => _membership());
      when(() => repository.searchPosts(any(), any(), any()))
          .thenAnswer((_) async => [post()]);
      when(() => repository.createPost(
            kind: any(named: 'kind'),
            communityId: any(named: 'communityId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
            linkUrl: any(named: 'linkUrl'),
            tagIds: any(named: 'tagIds'),
          )).thenAnswer((_) async => post(id: 'n2', tagIds: ['t1']));
    });

    test('add passes link and tags and puts the post first', () async {
      final c = container();
      final provider = publishedPostListProvider(PublishedKind.news);
      await c.read(provider.future);

      await c.read(provider.notifier).add(
            communityId: 'c1',
            title: 'News',
            body: 'Body',
            linkUrl: 'example.org',
            tagIds: ['t1'],
          );

      verify(() => repository.createPost(
            kind: PublishedKind.news,
            communityId: 'c1',
            title: 'News',
            body: 'Body',
            linkUrl: 'example.org',
            tagIds: ['t1'],
          )).called(1);
      expect(c.read(provider).value!.map((p) => p.id), ['n2', 'n1']);
    });

    test('each kind has its own query; changing it re-searches', () async {
      final c = container();
      final provider = publishedPostListProvider(PublishedKind.resource);
      await c.read(provider.future);

      c
          .read(postQueryProvider(PublishedKind.resource).notifier)
          .setSort(FeedSort.title);
      await c.read(provider.future);

      verify(() => repository.searchPosts(
            PublishedKind.resource,
            'c1',
            const FeedQuery(sort: FeedSort.title),
          )).called(1);
      expect(
        c.read(postQueryProvider(PublishedKind.news)).sort,
        FeedSort.newest,
      );
    });
  });

  group('isCommunityAdminProvider', () {
    ProviderContainer withProfile(String userId, UserRole role) =>
        ProviderContainer.test(
          overrides: [
            currentUserIdProvider.overrideWithValue(userId),
            communityRepositoryProvider.overrideWithValue(repository),
            currentProfileProvider.overrideWith(
              () => _FakeProfile(Profile(
                id: userId,
                role: role,
                firstName: 'A',
                lastName: 'B',
                email: 'a@b.c',
              )),
            ),
          ],
        );

    Future<bool> isAdmin(ProviderContainer c) async {
      await c.read(currentProfileProvider.future);
      await c.read(myMembershipProvider.future);
      return c.read(isCommunityAdminProvider);
    }

    setUp(() {
      when(() => repository.fetchMyMembership()).thenAnswer(
        (_) async => CommunityMembership(
          id: 'm1',
          communityId: 'c1',
          familyId: 'f1',
          joinedBy: 'dad',
          adminUserId: 'mom',
          joinedAt: DateTime(2026),
        ),
      );
    });

    test('the chosen adult is admin', () async {
      expect(await isAdmin(withProfile('mom', UserRole.parent)), isTrue);
    });

    test('their spouse in the same family is not', () async {
      expect(await isAdmin(withProfile('dad', UserRole.parent)), isFalse);
    });

    test('regional admins always are', () async {
      expect(
        await isAdmin(withProfile('ra', UserRole.regionalAdmin)),
        isTrue,
      );
    });
  });
}

class _FakeProfile extends CurrentProfile {
  _FakeProfile(this._profile);

  final Profile _profile;

  @override
  Future<Profile?> build() async => _profile;
}

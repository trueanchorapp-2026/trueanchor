import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:trueanchor/core/providers/supabase_providers.dart';
import 'package:trueanchor/features/community/application/community_providers.dart';
import 'package:trueanchor/features/community/domain/community_discussion.dart';
import 'package:trueanchor/features/community/domain/community_repository.dart';

class MockCommunityRepository extends Mock implements CommunityRepository {}

CommunityDiscussion _discussion({String? imageUrl}) => CommunityDiscussion(
      id: 'd1',
      communityId: 'c1',
      authorId: 'u1',
      title: 'Title',
      body: 'Body',
      imageUrl: imageUrl,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  late MockCommunityRepository repository;

  setUp(() {
    repository = MockCommunityRepository();
    when(() => repository.fetchMyMembership()).thenAnswer((_) async => null);
  });

  ProviderContainer container() => ProviderContainer.test(
        overrides: [
          currentUserIdProvider.overrideWithValue('u1'),
          communityRepositoryProvider.overrideWithValue(repository),
        ],
      );

  test('uploads the image first and stores its URL on the post', () async {
    when(() => repository.uploadDiscussionImage(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
        )).thenAnswer((_) async => 'https://x/u1/a.png');
    when(() => repository.createDiscussion(
          communityId: any(named: 'communityId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          imageUrl: any(named: 'imageUrl'),
        )).thenAnswer((_) async => _discussion(imageUrl: 'https://x/u1/a.png'));

    final c = container();
    await c.read(communityDiscussionListProvider.future);
    await c.read(communityDiscussionListProvider.notifier).add(
          communityId: 'c1',
          title: 'Title',
          body: 'Body',
          imageFileName: 'a.png',
          imageBytes: [1, 2, 3],
        );

    verify(() => repository.createDiscussion(
          communityId: 'c1',
          title: 'Title',
          body: 'Body',
          imageUrl: 'https://x/u1/a.png',
        )).called(1);
    expect(
      c.read(communityDiscussionListProvider).value?.single.imageUrl,
      'https://x/u1/a.png',
    );
  });

  test('skips the upload when no image was picked', () async {
    when(() => repository.createDiscussion(
          communityId: any(named: 'communityId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          imageUrl: any(named: 'imageUrl'),
        )).thenAnswer((_) async => _discussion());

    final c = container();
    await c.read(communityDiscussionListProvider.future);
    await c
        .read(communityDiscussionListProvider.notifier)
        .add(communityId: 'c1', title: 'Title', body: 'Body');

    verifyNever(() => repository.uploadDiscussionImage(
          fileName: any(named: 'fileName'),
          bytes: any(named: 'bytes'),
        ));
    verify(() => repository.createDiscussion(
          communityId: 'c1',
          title: 'Title',
          body: 'Body',
          imageUrl: null,
        )).called(1);
  });

  test('does not create the post if the upload fails', () async {
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
            imageFileName: 'a.png',
            imageBytes: [1],
          ),
      throwsException,
    );
    verifyNever(() => repository.createDiscussion(
          communityId: any(named: 'communityId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
          imageUrl: any(named: 'imageUrl'),
        ));
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/community.dart';
import '../domain/community_discussion.dart';
import '../domain/community_event.dart';
import '../domain/community_membership.dart';
import '../domain/community_repository.dart';
import '../domain/discussion_image.dart';
import '../domain/feed_query.dart';
import '../domain/published_post.dart';
import '../domain/region.dart';
import '../domain/topic_tag.dart';
import '../domain/vote.dart';
import '../infrastructure/supabase_community_repository.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => SupabaseCommunityRepository(ref.watch(supabaseClientProvider)),
);

// ── Regions ──────────────────────────────────────────────────────────────────

class RegionList extends AsyncNotifier<List<Region>> {
  @override
  Future<List<Region>> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(communityRepositoryProvider).fetchRegions();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({required String name}) async {
    final created =
        await ref.read(communityRepositoryProvider).createRegion(name: name);
    state = AsyncData([...state.value ?? const [], created]);
  }

  Future<void> remove(String regionId) async {
    await ref.read(communityRepositoryProvider).deleteRegion(regionId);
    state = AsyncData(
      (state.value ?? const []).where((r) => r.id != regionId).toList(),
    );
  }
}

final regionListProvider =
    AsyncNotifierProvider<RegionList, List<Region>>(RegionList.new);

// ── Communities ──────────────────────────────────────────────────────────────

class CommunityList extends AsyncNotifier<List<Community>> {
  @override
  Future<List<Community>> build() {
    ref.watch(currentUserIdProvider);
    return ref.watch(communityRepositoryProvider).fetchCommunities();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String regionId,
    required String name,
    String? city,
    String? state_,
  }) async {
    final created = await ref
        .read(communityRepositoryProvider)
        .createCommunity(
            regionId: regionId, name: name, city: city, state: state_);
    state = AsyncData([...state.value ?? const [], created]);
  }

  Future<void> edit({
    required String communityId,
    required String name,
    String? city,
    String? state_,
  }) async {
    final updated = await ref
        .read(communityRepositoryProvider)
        .updateCommunity(
            communityId: communityId, name: name, city: city, state: state_);
    state = AsyncData([
      for (final c in state.value ?? const <Community>[])
        if (c.id == communityId) updated else c,
    ]);
  }

  Future<void> remove(String communityId) async {
    await ref.read(communityRepositoryProvider).deleteCommunity(communityId);
    state = AsyncData(
      (state.value ?? const []).where((c) => c.id != communityId).toList(),
    );
  }
}

final communityListProvider =
    AsyncNotifierProvider<CommunityList, List<Community>>(CommunityList.new);

final communitiesByRegionProvider =
    FutureProvider.family<List<Community>, String>((ref, regionId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(communityRepositoryProvider)
      .fetchCommunities(regionId: regionId);
});

// ── My Membership ────────────────────────────────────────────────────────────

final myMembershipProvider =
    FutureProvider<CommunityMembership?>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(communityRepositoryProvider).fetchMyMembership();
});

final myCommunityProvider = FutureProvider<Community?>((ref) async {
  final membership = await ref.watch(myMembershipProvider.future);
  if (membership == null) return null;
  final communities = await ref.watch(communityListProvider.future);
  return communities
      .where((c) => c.id == membership.communityId)
      .firstOrNull;
});

/// Whether the signed-in user may manage their community's news, Parent Hub,
/// events and moderation. Community Admin is per person: other adults in the
/// admin's family are not admins.
final isCommunityAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentProfileProvider).value;
  if (profile == null) return false;
  if (profile.role.canManageRegions) return true;
  final membership = ref.watch(myMembershipProvider).value;
  return membership?.isAdminFor(ref.watch(currentUserIdProvider)) ?? false;
});

// ── Community Members ────────────────────────────────────────────────────────

final communityMembersProvider =
    FutureProvider.family<List<CommunityMembership>, String>(
        (ref, communityId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(communityRepositoryProvider)
      .fetchMembers(communityId);
});

// ── Community admin (regional admin view) ────────────────────────────────────

class CommunityAdminCandidates
    extends AsyncNotifier<List<CommunityAdminCandidate>> {
  CommunityAdminCandidates(this.communityId);

  final String communityId;

  @override
  Future<List<CommunityAdminCandidate>> build() {
    ref.watch(currentUserIdProvider);
    return ref
        .watch(communityRepositoryProvider)
        .fetchAdminCandidates(communityId);
  }

  /// Makes [userId] the community admin for their family's membership, or
  /// revokes it when [userId] is null.
  Future<void> setAdmin({
    required String membershipId,
    String? userId,
  }) async {
    await ref
        .read(communityRepositoryProvider)
        .setAdmin(membershipId: membershipId, userId: userId);
    ref.invalidate(myMembershipProvider);
    ref.invalidate(communityMembersProvider(communityId));
    state = await AsyncValue.guard(build);
  }
}

final communityAdminCandidatesProvider = AsyncNotifierProvider.family<
    CommunityAdminCandidates, List<CommunityAdminCandidate>, String>(
  CommunityAdminCandidates.new,
);

// ── Topic tags ───────────────────────────────────────────────────────────────

final topicTagsProvider = FutureProvider<List<TopicTag>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref.watch(communityRepositoryProvider).fetchTopicTags();
});

/// Tags by id, for labelling chips. Empty until tags load.
final topicTagsByIdProvider = Provider<Map<String, TopicTag>>((ref) => {
      for (final tag in ref.watch(topicTagsProvider).value ?? const <TopicTag>[])
        tag.id: tag,
    });

void _checkTagCount(List<String> tagIds) {
  if (tagIds.length > TopicTag.maxPerPost) {
    throw ArgumentError('At most ${TopicTag.maxPerPost} tags can be chosen.');
  }
}

// ── Feed queries ─────────────────────────────────────────────────────────────

/// Filter/search/sort state for one community feed.
class FeedQueryNotifier extends Notifier<FeedQuery> {
  @override
  FeedQuery build() {
    ref.watch(currentUserIdProvider);
    return const FeedQuery();
  }

  void toggleTag(String tagId) => state = state.toggleTag(tagId);
  void setText(String text) => state = state.copyWith(text: text);
  void setSort(FeedSort sort) => state = state.copyWith(sort: sort);
  void clear() => state = state.cleared();
}

final discussionQueryProvider =
    NotifierProvider<FeedQueryNotifier, FeedQuery>(FeedQueryNotifier.new);

/// News and Parent Hub each keep their own filters.
final postQueryProvider =
    NotifierProvider.family<FeedQueryNotifier, FeedQuery, PublishedKind>(
  (_) => FeedQueryNotifier(),
);

// ── News & Parent Hub ────────────────────────────────────────────────────────

class PublishedPostList extends AsyncNotifier<List<PublishedPost>> {
  PublishedPostList(this.kind);

  final PublishedKind kind;

  @override
  Future<List<PublishedPost>> build() async {
    ref.watch(currentUserIdProvider);
    final query = ref.watch(postQueryProvider(kind));
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null) return const [];
    return ref
        .watch(communityRepositoryProvider)
        .searchPosts(kind, membership.communityId, query);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String communityId,
    required String title,
    required String body,
    String? linkUrl,
    List<String> tagIds = const [],
  }) async {
    _checkTagCount(tagIds);
    final created = await ref.read(communityRepositoryProvider).createPost(
          kind: kind,
          communityId: communityId,
          title: title,
          body: body,
          linkUrl: linkUrl,
          tagIds: tagIds,
        );
    if (ref.read(postQueryProvider(kind)).newPostGoesFirst) {
      state = AsyncData([created, ...state.value ?? const []]);
    } else {
      await refresh();
    }
  }

  Future<void> edit({
    required String postId,
    required String title,
    required String body,
    String? linkUrl,
  }) async {
    final updated = await ref.read(communityRepositoryProvider).updatePost(
          kind: kind,
          postId: postId,
          title: title,
          body: body,
          linkUrl: linkUrl,
        );
    if (ref.read(postQueryProvider(kind)).isFiltered) {
      // The edit may change whether the post matches the search.
      await refresh();
    } else {
      _replace(postId, (_) => updated);
    }
    ref.invalidate(postByIdProvider((kind, postId)));
  }

  Future<void> updateTags({
    required String postId,
    required List<String> tagIds,
  }) async {
    _checkTagCount(tagIds);
    await ref
        .read(communityRepositoryProvider)
        .setPostTags(kind: kind, postId: postId, tagIds: tagIds);
    if (ref.read(postQueryProvider(kind)).tagIds.isNotEmpty) {
      await refresh();
    } else {
      _replace(postId, (p) => p.copyWith(tagIds: tagIds));
    }
    ref.invalidate(postByIdProvider((kind, postId)));
  }

  Future<void> remove(String postId) async {
    await ref.read(communityRepositoryProvider).deletePost(kind, postId);
    state = AsyncData(
      (state.value ?? const []).where((p) => p.id != postId).toList(),
    );
  }

  /// Applies the tap optimistically, then reconciles with the server's
  /// tally; rolls back and rethrows if the vote fails.
  Future<void> vote(PublishedPost post, int direction) async {
    final before = post.votes;
    final next = before.tap(direction);
    _replace(post.id, (p) => p.copyWith(votes: next));
    try {
      final saved = await ref.read(communityRepositoryProvider).castVote(
            target: kind.voteTarget,
            itemId: post.id,
            value: next.myVote,
          );
      _replace(post.id, (p) => p.copyWith(votes: saved));
    } catch (_) {
      _replace(post.id, (p) => p.copyWith(votes: before));
      rethrow;
    } finally {
      ref.invalidate(postByIdProvider((kind, post.id)));
    }
  }

  void _replace(String postId, PublishedPost Function(PublishedPost) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final p in current)
        if (p.id == postId) change(p) else p,
    ]);
  }
}

final publishedPostListProvider = AsyncNotifierProvider.family<
    PublishedPostList, List<PublishedPost>, PublishedKind>(
  PublishedPostList.new,
);

/// One post for its detail page: taken from the loaded list when present,
/// otherwise fetched (e.g. opened by link or hidden by the current filter).
final postByIdProvider =
    FutureProvider.family<PublishedPost?, (PublishedKind, String)>(
        (ref, key) async {
  ref.watch(currentUserIdProvider);
  final (kind, postId) = key;
  final listed = ref
      .read(publishedPostListProvider(kind))
      .value
      ?.where((p) => p.id == postId)
      .firstOrNull;
  if (listed != null) return listed;
  return ref.watch(communityRepositoryProvider).fetchPost(kind, postId);
});

/// Up to 5 discussions related to a news post (shared tags, then text).
final relatedDiscussionsProvider =
    FutureProvider.family<List<CommunityDiscussion>, String>((ref, newsId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(communityRepositoryProvider)
      .fetchRelatedDiscussions(newsId);
});

// ── Discussions ──────────────────────────────────────────────────────────────

class CommunityDiscussionList
    extends AsyncNotifier<List<CommunityDiscussion>> {
  @override
  Future<List<CommunityDiscussion>> build() async {
    ref.watch(currentUserIdProvider);
    final query = ref.watch(discussionQueryProvider);
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null) return const [];
    return ref
        .watch(communityRepositoryProvider)
        .searchDiscussions(membership.communityId, query);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String communityId,
    required String title,
    required String body,
    List<PendingImage> images = const [],
    List<String> tagIds = const [],
  }) async {
    _checkTagCount(tagIds);
    final repo = ref.read(communityRepositoryProvider);
    final imageUrls = await _uploadImages(repo, images);
    final created = await repo.createDiscussion(
      communityId: communityId,
      title: title,
      body: body,
      imageUrls: imageUrls,
      tagIds: tagIds,
    );
    // A new post belongs on top when nothing narrows the list and the sort
    // favours recent posts; otherwise let the server decide where it goes.
    if (ref.read(discussionQueryProvider).newPostGoesFirst) {
      state = AsyncData([created, ...state.value ?? const []]);
    } else {
      await refresh();
    }
  }

  Future<void> updateTags({
    required String discussionId,
    required List<String> tagIds,
  }) async {
    _checkTagCount(tagIds);
    await ref
        .read(communityRepositoryProvider)
        .setDiscussionTags(discussionId: discussionId, tagIds: tagIds);
    ref.invalidate(discussionByIdProvider(discussionId));
    if (ref.read(discussionQueryProvider).tagIds.isNotEmpty) {
      // The post may no longer match the active tag filter.
      await refresh();
      return;
    }
    _replace(discussionId, (d) => d.copyWith(tagIds: tagIds));
  }

  /// Reflects a new reply in the list without a refetch (or reorder).
  void noteReplyAdded(String discussionId) {
    _replace(
      discussionId,
      (d) => d.copyWith(
        replyCount: (d.replyCount ?? 0) + 1,
        lastActivityAt: DateTime.now(),
      ),
    );
  }

  Future<void> edit({
    required String discussionId,
    required String title,
    required String body,
  }) async {
    final updated = await ref
        .read(communityRepositoryProvider)
        .updateDiscussion(
            discussionId: discussionId, title: title, body: body);
    ref.invalidate(discussionByIdProvider(discussionId));
    _replace(discussionId, (_) => updated);
  }

  Future<void> remove(String discussionId) async {
    await ref
        .read(communityRepositoryProvider)
        .deleteDiscussion(discussionId);
    state = AsyncData(
      (state.value ?? const []).where((d) => d.id != discussionId).toList(),
    );
  }

  /// Optimistic up/down vote; rolls back and rethrows on failure.
  Future<void> vote(CommunityDiscussion discussion, int direction) async {
    final before = discussion.votes;
    final next = before.tap(direction);
    _replace(discussion.id, (d) => d.copyWith(votes: next));
    try {
      final saved = await ref.read(communityRepositoryProvider).castVote(
            target: VoteTarget.discussion,
            itemId: discussion.id,
            value: next.myVote,
          );
      _replace(discussion.id, (d) => d.copyWith(votes: saved));
    } catch (_) {
      _replace(discussion.id, (d) => d.copyWith(votes: before));
      rethrow;
    } finally {
      ref.invalidate(discussionByIdProvider(discussion.id));
    }
  }

  void _replace(
    String discussionId,
    CommunityDiscussion Function(CommunityDiscussion) change,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final d in current)
        if (d.id == discussionId) change(d) else d,
    ]);
  }
}

final communityDiscussionListProvider =
    AsyncNotifierProvider<CommunityDiscussionList,
        List<CommunityDiscussion>>(CommunityDiscussionList.new);

/// One discussion for its detail page: from the loaded list when present,
/// otherwise fetched (e.g. opened from a news post's related discussions).
final discussionByIdProvider =
    FutureProvider.family<CommunityDiscussion?, String>(
        (ref, discussionId) async {
  ref.watch(currentUserIdProvider);
  final listed = ref
      .read(communityDiscussionListProvider)
      .value
      ?.where((d) => d.id == discussionId)
      .firstOrNull;
  if (listed != null) return listed;
  return ref.watch(communityRepositoryProvider).fetchDiscussion(discussionId);
});

/// Uploads [images] in parallel, keeping their order, before the post or
/// reply that references them is written. Over the cap fails before anything
/// is uploaded, rather than at the database check afterwards.
Future<List<String>> _uploadImages(
  CommunityRepository repo,
  List<PendingImage> images,
) {
  if (images.length > DiscussionImages.maxPerEntry) {
    throw ArgumentError(
      'At most ${DiscussionImages.maxPerEntry} images can be attached.',
    );
  }
  return Future.wait([
    for (final image in images)
      repo.uploadDiscussionImage(fileName: image.fileName, bytes: image.bytes),
  ]);
}

// ── Replies ──────────────────────────────────────────────────────────────────

class DiscussionReplies extends AsyncNotifier<List<DiscussionReply>> {
  DiscussionReplies(this.discussionId);

  final String discussionId;

  @override
  Future<List<DiscussionReply>> build() {
    ref.watch(currentUserIdProvider);
    return ref
        .watch(communityRepositoryProvider)
        .fetchReplies(discussionId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String body,
    List<PendingImage> images = const [],
  }) async {
    final repo = ref.read(communityRepositoryProvider);
    final imageUrls = await _uploadImages(repo, images);
    final created = await repo.createReply(
      discussionId: discussionId,
      body: body,
      imageUrls: imageUrls,
    );
    state = AsyncData([...state.value ?? const [], created]);
    ref
        .read(communityDiscussionListProvider.notifier)
        .noteReplyAdded(discussionId);
  }

  Future<void> remove(String replyId) async {
    await ref.read(communityRepositoryProvider).deleteReply(replyId);
    state = AsyncData(
      (state.value ?? const []).where((r) => r.id != replyId).toList(),
    );
  }

  /// Optimistically toggles "helpful"; rolls back and rethrows on failure.
  Future<void> toggleHelpful(String replyId) async {
    final before =
        state.value?.where((r) => r.id == replyId).firstOrNull;
    if (before == null) return;
    _replace(replyId, (r) => r.toggledHelpful());
    try {
      final saved =
          await ref.read(communityRepositoryProvider).toggleReplyHelpful(replyId);
      _replace(
        replyId,
        (r) => r.copyWith(
          helpfulCount: saved.helpfulCount,
          markedHelpfulByMe: saved.markedByMe,
        ),
      );
    } catch (_) {
      _replace(replyId, (_) => before);
      rethrow;
    }
  }

  void _replace(
    String replyId,
    DiscussionReply Function(DiscussionReply) change,
  ) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        if (r.id == replyId) change(r) else r,
    ]);
  }
}

final discussionRepliesProvider = AsyncNotifierProvider.family<
    DiscussionReplies, List<DiscussionReply>, String>(
  DiscussionReplies.new,
);

// ── Events ───────────────────────────────────────────────────────────────────

class CommunityEventList extends AsyncNotifier<List<CommunityEvent>> {
  @override
  Future<List<CommunityEvent>> build() async {
    ref.watch(currentUserIdProvider);
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null) return const [];
    return ref
        .watch(communityRepositoryProvider)
        .fetchEvents(membership.communityId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String communityId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    final created = await ref
        .read(communityRepositoryProvider)
        .createEvent(
          communityId: communityId,
          title: title,
          description: description,
          location: location,
          startsAt: startsAt,
          endsAt: endsAt,
        );
    state = AsyncData([...state.value ?? const [], created]);
  }

  Future<void> edit({
    required String eventId,
    required String title,
    String? description,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
  }) async {
    final updated = await ref
        .read(communityRepositoryProvider)
        .updateEvent(
          eventId: eventId,
          title: title,
          description: description,
          location: location,
          startsAt: startsAt,
          endsAt: endsAt,
        );
    state = AsyncData([
      for (final e in state.value ?? const <CommunityEvent>[])
        if (e.id == eventId) updated else e,
    ]);
  }

  Future<void> remove(String eventId) async {
    await ref.read(communityRepositoryProvider).deleteEvent(eventId);
    state = AsyncData(
      (state.value ?? const []).where((e) => e.id != eventId).toList(),
    );
  }
}

final communityEventListProvider =
    AsyncNotifierProvider<CommunityEventList, List<CommunityEvent>>(
        CommunityEventList.new);


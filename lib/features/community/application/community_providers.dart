import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../domain/community.dart';
import '../domain/community_discussion.dart';
import '../domain/community_event.dart';
import '../domain/community_membership.dart';
import '../domain/community_news.dart';
import '../domain/community_repository.dart';
import '../domain/region.dart';
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

// ── Community Members ────────────────────────────────────────────────────────

final communityMembersProvider =
    FutureProvider.family<List<CommunityMembership>, String>(
        (ref, communityId) {
  ref.watch(currentUserIdProvider);
  return ref
      .watch(communityRepositoryProvider)
      .fetchMembers(communityId);
});

// ── News ─────────────────────────────────────────────────────────────────────

class CommunityNewsList extends AsyncNotifier<List<CommunityNewsItem>> {
  @override
  Future<List<CommunityNewsItem>> build() async {
    ref.watch(currentUserIdProvider);
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null) return const [];
    return ref
        .watch(communityRepositoryProvider)
        .fetchNews(membership.communityId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String communityId,
    required String title,
    required String body,
  }) async {
    final created = await ref
        .read(communityRepositoryProvider)
        .createNews(communityId: communityId, title: title, body: body);
    state = AsyncData([created, ...state.value ?? const []]);
  }

  Future<void> edit({
    required String newsId,
    required String title,
    required String body,
  }) async {
    final updated = await ref
        .read(communityRepositoryProvider)
        .updateNews(newsId: newsId, title: title, body: body);
    state = AsyncData([
      for (final n in state.value ?? const <CommunityNewsItem>[])
        if (n.id == newsId) updated else n,
    ]);
  }

  Future<void> remove(String newsId) async {
    await ref.read(communityRepositoryProvider).deleteNews(newsId);
    state = AsyncData(
      (state.value ?? const []).where((n) => n.id != newsId).toList(),
    );
  }
}

final communityNewsListProvider =
    AsyncNotifierProvider<CommunityNewsList, List<CommunityNewsItem>>(
        CommunityNewsList.new);

// ── Discussions ──────────────────────────────────────────────────────────────

class CommunityDiscussionList
    extends AsyncNotifier<List<CommunityDiscussion>> {
  @override
  Future<List<CommunityDiscussion>> build() async {
    ref.watch(currentUserIdProvider);
    final membership = await ref.watch(myMembershipProvider.future);
    if (membership == null) return const [];
    return ref
        .watch(communityRepositoryProvider)
        .fetchDiscussions(membership.communityId);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> add({
    required String communityId,
    required String title,
    required String body,
  }) async {
    final created = await ref
        .read(communityRepositoryProvider)
        .createDiscussion(
            communityId: communityId, title: title, body: body);
    state = AsyncData([created, ...state.value ?? const []]);
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
    state = AsyncData([
      for (final d in state.value ?? const <CommunityDiscussion>[])
        if (d.id == discussionId) updated else d,
    ]);
  }

  Future<void> remove(String discussionId) async {
    await ref
        .read(communityRepositoryProvider)
        .deleteDiscussion(discussionId);
    state = AsyncData(
      (state.value ?? const []).where((d) => d.id != discussionId).toList(),
    );
  }
}

final communityDiscussionListProvider =
    AsyncNotifierProvider<CommunityDiscussionList,
        List<CommunityDiscussion>>(CommunityDiscussionList.new);

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

  Future<void> add({required String body}) async {
    final created = await ref
        .read(communityRepositoryProvider)
        .createReply(discussionId: discussionId, body: body);
    state = AsyncData([...state.value ?? const [], created]);
  }

  Future<void> remove(String replyId) async {
    await ref.read(communityRepositoryProvider).deleteReply(replyId);
    state = AsyncData(
      (state.value ?? const []).where((r) => r.id != replyId).toList(),
    );
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
